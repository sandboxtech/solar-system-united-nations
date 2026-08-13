local config = require('config')
local factions = require('scripts.factions')
local properties = require('scripts.properties')
local surfaces = require('scripts.surfaces')

local M = {}

local planet_indexes = {}
for index, name in ipairs(config.public_planets) do
    planet_indexes[name] = index
end

local function link_id(planet_name)
    return config.faction_logistics_link_id_base + planet_indexes[planet_name]
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
    for _, position in ipairs(chest_positions) do
        local chest = surface.find_entity(config.linked_chest_name, position)
        if chest and chest.valid and chest.link_id ~= link_id(planet_name) then
            log('[un] faction logistics chest position occupied on '
                .. surface.name)
            return false
        end
        if not (chest and chest.valid) then
            chest = surface.create_entity{
                name = config.linked_chest_name,
                position = position,
                force = force,
                raise_built = false,
            }
        end
        if not (chest and chest.valid) then return false end
        chest.link_id = link_id(planet_name)
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
    return M.ensure_on_surface(
        game.surfaces[planet_name],
        planet_name,
        true,
        config.faction_logistics_chest_positions,
        config.faction_logistics_loader_offset,
        defines.direction.south,
        'output'
    )
end

function M.ensure_hospice(planet_name)
    return M.ensure_on_surface(
        surfaces.hospice_surface(planet_name),
        planet_name,
        false,
        config.faction_logistics_hospice_chest_positions,
        config.faction_logistics_hospice_loader_offset,
        defines.direction.north,
        'output'
    )
end

function M.ensure_all()
    for _, planet_name in ipairs(config.public_planets) do
        M.ensure_hospice(planet_name)
        M.ensure_planet(planet_name)
    end
end

local function migrate_chests(surface, planet_name, old_positions,
        target_positions)
    local changed = 0
    local expected_link_id = link_id(planet_name)
    local targets = {}
    for _, position in ipairs(target_positions or {}) do
        targets[position.x .. ',' .. position.y] = true
    end
    for _, old_position in ipairs(old_positions) do
        if not targets[old_position.x .. ',' .. old_position.y] then
            local old = surface.find_entity(config.linked_chest_name, old_position)
            if old and old.valid and old.link_id == expected_link_id then
                old.destroy()
                changed = changed + 1
            end
        end
    end
    return changed
end

local function destroy_managed_loaders(surface, force, positions)
    local changed = 0
    for _, position in ipairs(positions) do
        local loader = surface.find_entity(
            config.property_linked_loader_name,
            position
        )
        if loader and loader.valid and loader.force == force then
            loader.destroy()
            changed = changed + 1
        end
    end
    return changed
end

local function migrate_station(surface, planet_name, old_position)
    local old = surface.find_entity(
        config.faction_logistics_station_name,
        old_position
    )
    if not (old and old.valid) then return 0, 0 end
    local force = factions.of_planet(planet_name)
    if old.force ~= force then return 0, 1 end
    local target = surface.find_entity(
        config.faction_logistics_station_name,
        config.faction_logistics_station_position
    )
    if target and target.valid and target ~= old then
        local main = target.get_inventory(
            defines.inventory.cargo_landing_pad_main
        )
        local trash = target.get_inventory(
            defines.inventory.cargo_landing_pad_trash
        )
        if (main and not main.is_empty()) or (trash and not trash.is_empty()) then
            return 0, 1
        end
        target.destroy()
    end
    if old.teleport(
        config.faction_logistics_station_position,
        surface,
        false,
        false
    ) then
        return 1, 0
    end
    return 0, 1
end

function M.migrate_layout()
    local changed = 0
    local failed = 0
    local failures = {}
    local function fail(message)
        failed = failed + 1
        failures[#failures + 1] = message
        log('[un] logistics layout migration failed: ' .. message)
    end
    for _, planet_name in ipairs(config.public_planets) do
        local planet_surface = game.surfaces[planet_name]
        if planet_surface and planet_surface.valid then
            local force = factions.of_planet(planet_name)
            local moved = migrate_chests(
                planet_surface,
                planet_name,
                {
                    {x = -2, y = 0},
                    {x = -1, y = 0},
                    {x = 0, y = 0},
                    {x = 1, y = 0},
                    {x = -2, y = 1},
                    {x = -1, y = 1},
                    {x = 0, y = 1},
                    {x = 1, y = 1},
                },
                config.faction_logistics_chest_positions
            )
            changed = changed + moved
            changed = changed + destroy_managed_loaders(
                planet_surface,
                force,
                {
                    {x = -2, y = 1},
                    {x = -1, y = 1},
                    {x = 0, y = 1},
                    {x = 1, y = 1},
                }
            )
            local errors
            moved, errors = migrate_station(
                planet_surface, planet_name, {x = 0, y = -4}
            )
            changed = changed + moved
            if errors > 0 then fail('station ' .. planet_name .. ' at 0,-4') end
            moved, errors = migrate_station(
                planet_surface, planet_name, {x = 0, y = -8}
            )
            changed = changed + moved
            if errors > 0 then fail('station ' .. planet_name .. ' at 0,-8') end
            if not M.ensure_planet(planet_name) then
                fail('public planet ' .. planet_name)
            end
        end

        local hospice = game.surfaces[surfaces.hospice_surface_name(planet_name)]
        if hospice and hospice.valid then
            local force = factions.of_planet(planet_name)
            local moved = migrate_chests(
                hospice,
                planet_name,
                {
                    {x = -2, y = -1},
                    {x = -1, y = -1},
                    {x = 0, y = -1},
                    {x = 1, y = -1},
                    {x = -2, y = 3},
                    {x = -1, y = 3},
                    {x = 0, y = 3},
                    {x = 1, y = 3},
                    {x = -2, y = 0},
                    {x = -1, y = 0},
                    {x = 0, y = 0},
                    {x = 1, y = 0},
                },
                config.faction_logistics_hospice_chest_positions
            )
            changed = changed + moved
            changed = changed + destroy_managed_loaders(
                hospice,
                force,
                {
                    {x = -2, y = -1},
                    {x = -1, y = -1},
                    {x = 0, y = -1},
                    {x = 1, y = -1},
                    {x = -2, y = 1},
                    {x = -1, y = 1},
                    {x = 0, y = 1},
                    {x = 1, y = 1},
                    {x = -2, y = 2},
                    {x = -1, y = 2},
                    {x = 0, y = 2},
                    {x = 1, y = 2},
                }
            )
            if surfaces.rebuild_hospice_layout(planet_name) then
                changed = changed + 1
            else
                fail('refugee camp terrain ' .. planet_name)
            end
            if not M.ensure_hospice(planet_name) then
                fail('refugee camp logistics ' .. planet_name)
            end
        end
    end
    local rebuilt, property_failures, property_failure_details
        = properties.migrate_permanent_rental_layouts()
    changed = changed + rebuilt
    failed = failed + property_failures
    for _, detail in ipairs(property_failure_details or {}) do
        failures[#failures + 1] = detail
        log('[un] logistics layout migration failed: ' .. detail)
    end
    return changed, failed, failures
end

local function migration_command(command)
    local player = command.player_index and game.get_player(command.player_index)
    if player and not player.admin then
        player.print({'un.admin-only'})
        return
    end
    local changed, failed, failures = M.migrate_layout()
    local message = {'un.logistics-layout-migration-result', changed, failed}
    local function output(value)
        if player then player.print(value) else localised_print(value) end
    end
    output(message)
    for _, detail in ipairs(failures) do
        output({'un.logistics-layout-migration-failure', detail})
    end
end

commands.add_command(
    'un-migrate-logistics-layout',
    {'un.logistics-layout-migration-help'},
    migration_command
)

return M
