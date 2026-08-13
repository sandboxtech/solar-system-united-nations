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

function M.ensure_on_surface(surface, planet_name, with_station, chest_positions,
        legacy_positions)
    local force = factions.of_planet(planet_name)
    if not (surface and surface.valid and force and force.valid) then return false end
    chest_positions = chest_positions or config.faction_logistics_chest_positions
    local station_position = config.faction_logistics_station_position
    if with_station then
        local station = surface.find_entity(
            config.faction_logistics_station_name,
            station_position
        )
        if station and station.valid and station.force ~= force then
            log('[un] faction logistics station position occupied on '
                .. surface.name)
            return false
        end
        if not (station and station.valid) then
            station = surface.create_entity{
                name = config.faction_logistics_station_name,
                position = station_position,
                force = force,
                raise_built = false,
            }
        end
        if not (station and station.valid) then return false end
        protect(station)
    end
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
    end
    return true
end

function M.ensure_planet(planet_name)
    return M.ensure_on_surface(game.surfaces[planet_name], planet_name, true)
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
