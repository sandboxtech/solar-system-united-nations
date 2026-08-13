local config = require('config')
local factions = require('scripts.factions')
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

local function ensure_loader(surface, force, chest_position, offset)
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
            direction = defines.direction.north,
            force = force,
            raise_built = false,
        }
    end
    if not (loader and loader.valid) then return false end
    loader.rotatable = true
    protect(loader)
    return true
end

function M.ensure_on_surface(surface, planet_name, with_station, chest_positions,
        loader_offset)
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
                and not ensure_loader(surface, force, position, loader_offset) then
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
        config.faction_logistics_loader_offset
    )
end

function M.ensure_hospice(planet_name)
    return M.ensure_on_surface(
        surfaces.hospice_surface(planet_name),
        planet_name,
        false,
        config.faction_logistics_hospice_chest_positions,
        config.faction_logistics_hospice_loader_offset
    )
end

function M.ensure_all()
    for _, planet_name in ipairs(config.public_planets) do
        M.ensure_hospice(planet_name)
        M.ensure_planet(planet_name)
    end
end

local function migrate_chests(surface, planet_name, old_positions)
    local changed = 0
    local expected_link_id = link_id(planet_name)
    for _, old_position in ipairs(old_positions) do
        local old = surface.find_entity(config.linked_chest_name, old_position)
        if old and old.valid and old.link_id == expected_link_id then
            old.destroy()
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
    for _, planet_name in ipairs(config.public_planets) do
        local planet_surface = game.surfaces[planet_name]
        if planet_surface and planet_surface.valid then
            local moved = migrate_chests(
                planet_surface,
                planet_name,
                {
                    {x = -2, y = 0},
                    {x = -1, y = 0},
                    {x = 0, y = 0},
                    {x = 1, y = 0},
                }
            )
            changed = changed + moved
            local errors
            moved, errors = migrate_station(
                planet_surface, planet_name, {x = 0, y = -8}
            )
            changed = changed + moved
            failed = failed + errors
            if not M.ensure_planet(planet_name) then failed = failed + 1 end
        end

        local hospice = game.surfaces[surfaces.hospice_surface_name(planet_name)]
        if hospice and hospice.valid then
            local moved = migrate_chests(
                hospice,
                planet_name,
                {
                    {x = -2, y = 3},
                    {x = -1, y = 3},
                    {x = 0, y = 3},
                    {x = 1, y = 3},
                }
            )
            changed = changed + moved
            if not M.ensure_hospice(planet_name) then failed = failed + 1 end
        end
    end
    return changed, failed
end

local function migration_command(command)
    local player = command.player_index and game.get_player(command.player_index)
    if player and not player.admin then
        player.print({'un.admin-only'})
        return
    end
    local changed, failed = M.migrate_layout()
    local message = {'un.logistics-layout-migration-result', changed, failed}
    if player then player.print(message) else localised_print(message) end
end

commands.add_command(
    'un-migrate-logistics-layout',
    {'un.logistics-layout-migration-help'},
    migration_command
)

return M
