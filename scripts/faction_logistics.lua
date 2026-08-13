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

local function move_legacy_chest(surface, planet_name, legacy_positions,
        index, target_position)
    local legacy_position = legacy_positions and legacy_positions[index]
    if not legacy_position then return nil end
    local chest = surface.find_entity(config.linked_chest_name, legacy_position)
    if not (chest and chest.valid and chest.link_id == link_id(planet_name)) then
        return nil
    end
    if chest.teleport(target_position, surface, false, false) then return chest end
    log('[un] could not move faction logistics chest on ' .. surface.name
        .. ' from ' .. legacy_position.x .. ',' .. legacy_position.y
        .. ' to ' .. target_position.x .. ',' .. target_position.y)
    return nil
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
        local legacy_position = config.faction_logistics_legacy_station_position
        local legacy = legacy_position and surface.find_entity(
            config.faction_logistics_station_name,
            legacy_position
        )
        if legacy and legacy.valid and legacy.force == force
                and legacy.teleport(position, surface, false, false) then
            station = legacy
        end
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

local function ensure_loader(surface, force, chest_position)
    local offset = config.faction_logistics_loader_offset
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
        legacy_positions)
    local force = factions.of_planet(planet_name)
    if not (surface and surface.valid and force and force.valid) then return false end
    chest_positions = chest_positions or config.faction_logistics_chest_positions
    for index, position in ipairs(chest_positions) do
        local chest = surface.find_entity(config.linked_chest_name, position)
        if not (chest and chest.valid) then
            chest = move_legacy_chest(
                surface, planet_name, legacy_positions, index, position
            )
        end
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
        if with_station and not ensure_loader(surface, force, position) then
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
        config.faction_logistics_legacy_chest_positions
    )
end

function M.ensure_hospice(planet_name)
    return M.ensure_on_surface(
        surfaces.hospice_surface(planet_name),
        planet_name,
        false,
        config.faction_logistics_hospice_chest_positions,
        config.faction_logistics_hospice_legacy_chest_positions
    )
end

function M.ensure_all()
    for _, planet_name in ipairs(config.public_planets) do
        M.ensure_hospice(planet_name)
        M.ensure_planet(planet_name)
    end
end

return M
