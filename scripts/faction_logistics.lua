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

function M.ensure_on_surface(surface, planet_name, with_station)
    local force = factions.of_planet(planet_name)
    if not (surface and surface.valid and force and force.valid) then return false end
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
    for _, position in ipairs(config.faction_logistics_chest_positions) do
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
        false
    )
end

function M.ensure_all()
    for _, planet_name in ipairs(config.public_planets) do
        M.ensure_hospice(planet_name)
        M.ensure_planet(planet_name)
    end
end

return M
