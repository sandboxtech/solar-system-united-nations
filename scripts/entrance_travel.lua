local events = require('scripts.events')
local factions = require('scripts.factions')
local properties = require('scripts.properties')
local surfaces = require('scripts.surfaces')

local function entrance_context(player)
    local surface = player.physical_surface
    local planet_name = factions.of_player(player)
    if not (surface and surface.valid and planet_name) then return nil end
    if surface.name == planet_name then
        return 'planet', planet_name, 0
    end
    if surfaces.hospice_planet(surface) == planet_name then
        return 'hospice', planet_name, -2
    end
    local property = properties.on_surface(surface)
    if property and property.sample_planet == planet_name then
        return 'property', planet_name, 1
    end
    return nil
end

local function changed_position(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid and player.character
            and player.character.valid) then
        return
    end
    -- Moving the remote-view camera must never move the physical character.
    if player.controller_type == defines.controllers.remote then return end
    local position = player.physical_position
    local surface = player.physical_surface
    local lock = storage.entrance_travel_locks[player.index]
    if lock then
        if surface and surface.valid
                and surface.index == lock.surface_index
                and surfaces.is_entrance_position(position, lock.top_y) then
            return
        end
        storage.entrance_travel_locks[player.index] = nil
    end
    if player.physical_vehicle and player.physical_vehicle.valid then return end
    local context, planet_name, top_y = entrance_context(player)
    if not context or not surfaces.is_entrance_position(position, top_y) then
        return
    end
    if context == 'planet' or context == 'property' then
        surfaces.to_hospice(player, planet_name)
    else
        surfaces.to_planet_origin(player, planet_name)
    end
end

events.on(defines.events.on_player_changed_position, changed_position)
events.on(defines.events.on_player_removed, function(event)
    storage.entrance_travel_locks[event.player_index] = nil
end)
