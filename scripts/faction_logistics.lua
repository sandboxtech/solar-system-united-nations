local config = require('config')
local factions = require('scripts.factions')
local surfaces = require('scripts.surfaces')

local M = {}

local planet_indexes = {}
for index, name in ipairs(config.public_planets) do
    planet_indexes[name] = index
end

local function legacy_link_id(planet_name)
    return config.faction_logistics_link_id_base + planet_indexes[planet_name]
end

local function link_id(planet_name, slot)
    return config.faction_logistics_link_id_base
        + #config.public_planets
        + (planet_indexes[planet_name] - 1) * 4 + slot
end

local function snapshot_inventory(source)
    if not (source and source.valid) then return nil end
    local snapshot = game.create_inventory(#source)
    for index = 1, #source do
        local stack = source[index]
        if stack.valid_for_read
                and not snapshot[index].set_stack(stack) then
            snapshot.destroy()
            return nil
        end
    end
    return snapshot
end

local function destroy_snapshots(snapshots)
    for _, snapshot in pairs(snapshots) do
        if snapshot.valid then snapshot.destroy() end
    end
end

local function has_legacy_layout()
    for _, planet_name in ipairs(config.public_planets) do
        local old_id = legacy_link_id(planet_name)
        local checks = {
            {
                surface = surfaces.hospice_surface(planet_name),
                positions = config.faction_logistics_hospice_chest_positions,
            },
            {
                surface = game.surfaces[planet_name],
                positions = config.faction_logistics_chest_positions,
            },
        }
        for _, check in ipairs(checks) do
            if check.surface and check.surface.valid then
                for _, position in ipairs(check.positions) do
                    local chest = check.surface.find_entity(
                        config.linked_chest_name,
                        position
                    )
                    if chest and chest.valid and chest.link_id == old_id then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function protect(entity)
    entity.destructible = false
    entity.minable_flag = false
end

local function ensure_station(surface, force)
    local position = config.faction_logistics_station_position
    local station = surface.find_entity(config.faction_logistics_station_name, position)
    if station and station.valid and station.force ~= force then
        log('[un] faction logistics station position occupied on '
            .. surface.name)
        return false
    end
    if not (station and station.valid) then
        station = surface.create_entity{
            name = config.faction_logistics_station_name,
            position = position,
            force = force,
            raise_built = false,
        }
    end
    if not (station and station.valid) then return false end
    protect(station)
    return true
end

local function ensure_loader(surface, force, chest_position, offset,
        direction, loader_type)
    local position = {
        x = chest_position.x + offset.x,
        y = chest_position.y + offset.y,
    }
    local loader = surface.find_entity(config.property_linked_loader_name, position)
    if loader and loader.valid and loader.force ~= force then
        log('[un] faction logistics loader position occupied on '
            .. surface.name)
        return false
    end
    if not (loader and loader.valid) then
        loader = surface.create_entity{
            name = config.property_linked_loader_name,
            position = position,
            direction = direction,
            force = force,
            raise_built = false,
        }
    end
    if not (loader and loader.valid) then return false end
    loader.direction = direction
    loader.loader_type = loader_type
    loader.rotatable = true
    protect(loader)
    return true
end

function M.ensure_on_surface(surface, planet_name, with_station, chest_positions,
        loader_offset, loader_direction, loader_type)
    local force = factions.of_planet(planet_name)
    if not (surface and surface.valid and force and force.valid) then return false end
    chest_positions = chest_positions or config.faction_logistics_chest_positions
    for slot, position in ipairs(chest_positions) do
        local chest = surface.find_entity(config.linked_chest_name, position)
        if not (chest and chest.valid) then
            chest = surface.create_entity{
                name = config.linked_chest_name,
                position = position,
                force = force,
                raise_built = false,
            }
        end
        if not (chest and chest.valid) then return false end
        chest.link_id = link_id(planet_name, slot)
        chest.operable = false
        protect(chest)
        if loader_offset
                and not ensure_loader(
                    surface,
                    force,
                    position,
                    loader_offset,
                    loader_direction or defines.direction.north,
                    loader_type or 'output'
                ) then
            return false
        end
    end
    if with_station and not ensure_station(surface, force) then return false end
    return true
end

function M.ensure_planet(planet_name)
    local surface = game.surfaces[planet_name]
    if not (surface and surface.valid) then return false end
    surfaces.apply_entrance_tiles(surface, 0)
    return M.ensure_on_surface(
        surface,
        planet_name,
        true,
        config.faction_logistics_chest_positions,
        config.faction_logistics_loader_offset,
        defines.direction.south,
        'output'
    )
end

function M.ensure_hospice(planet_name)
    local surface = surfaces.hospice_surface(planet_name)
    if not (surface and surface.valid) then return false end
    surfaces.apply_entrance_tiles(surface, config.property_entrance_top_y)
    return M.ensure_on_surface(
        surface,
        planet_name,
        false,
        config.faction_logistics_hospice_chest_positions,
        config.faction_logistics_hospice_loader_offset,
        defines.direction.north,
        'output'
    )
end

function M.ensure_all()
    local migrate = has_legacy_layout()
    local snapshots = {}
    if migrate then
        for _, planet_name in ipairs(config.public_planets) do
            local force = factions.of_planet(planet_name)
            if force and force.valid then
                local old_inventory = force.get_linked_inventory(
                    config.linked_chest_name,
                    legacy_link_id(planet_name)
                )
                local snapshot = snapshot_inventory(old_inventory)
                if old_inventory and old_inventory.valid and not snapshot then
                    destroy_snapshots(snapshots)
                    return
                end
                if snapshot then snapshots[planet_name] = snapshot end
            end
        end
    end

    local complete = true
    for _, planet_name in ipairs(config.public_planets) do
        if not M.ensure_hospice(planet_name) then complete = false end
        if not M.ensure_planet(planet_name) then complete = false end
    end

    if migrate and complete then
        for _, planet_name in ipairs(config.public_planets) do
            local source = snapshots[planet_name]
            local force = factions.of_planet(planet_name)
            local target = force and force.valid and force.get_linked_inventory(
                config.linked_chest_name,
                link_id(planet_name, 1)
            ) or nil
            if source and source.valid and target and target.valid then
                for index = 1, #source do
                    local source_stack = source[index]
                    if source_stack.valid_for_read
                            and not target[index].set_stack(source_stack) then
                            complete = false
                            break
                    end
                end
            elseif source and source.valid then
                complete = false
            end
            if not complete then break end
        end
    end
    if migrate and complete then
        for _, planet_name in ipairs(config.public_planets) do
            local force = factions.of_planet(planet_name)
            local old_inventory = force and force.valid
                and force.get_linked_inventory(
                    config.linked_chest_name,
                    legacy_link_id(planet_name)
                ) or nil
            if old_inventory and old_inventory.valid then
                old_inventory.clear()
            end
        end
    end
    destroy_snapshots(snapshots)
end

return M
