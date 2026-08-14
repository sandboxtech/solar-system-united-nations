local factions = require('scripts.factions')
local properties = require('scripts.properties')
local surfaces = require('scripts.surfaces')

local M = {name = 'un_hud_property_cycle'}

local function owned_home_properties(player, planet_name)
    local result = {}
    for _, property in ipairs(properties.list(planet_name)) do
        local surface = game.surfaces[property.surface_name]
        if property.owner_index == player.index
                and surface and surface.valid then
            result[#result + 1] = property
        end
    end
    return result
end

local function context(player)
    if not (player and player.valid and player.character
            and player.character.valid) then
        return nil, 'location'
    end
    if player.physical_vehicle and player.physical_vehicle.valid then
        return nil, 'vehicle'
    end
    local home_planet = factions.of_player(player)
    if not home_planet then return nil, 'location' end
    local _, hospice_planet = surfaces.hospice_floor(player.physical_surface)
    if hospice_planet == home_planet then
        return {
            home_planet = home_planet,
            surface_name = player.physical_surface.name,
        }
    end
    local property = properties.on_surface(player.physical_surface)
    if property and property.sample_planet == home_planet then
        return {
            home_planet = home_planet,
            surface_name = player.physical_surface.name,
        }
    end
    return nil, 'location'
end

local function destinations(player, home_planet)
    local result = {
        {
            kind = 'hospice',
            floor = 1,
            entrance = 'lower',
            surface_name = surfaces.hospice_surface_name(home_planet, 1),
            caption = {
                'un.hospice-name-planet',
                {'space-location-name.' .. home_planet},
            },
        },
        {
            kind = 'hospice',
            floor = 2,
            entrance = 'upper',
            surface_name = surfaces.hospice_surface_name(home_planet, 2),
            caption = {
                'un.hospice-name-planet-basement',
                {'space-location-name.' .. home_planet},
            },
        },
    }
    for _, property in ipairs(owned_home_properties(player, home_planet)) do
        result[#result + 1] = {
            kind = 'property',
            surface_name = property.surface_name,
            caption = properties.surface_display_name(property),
        }
    end
    return result
end

local function next_destination(player, current)
    local route = destinations(player, current.home_planet)
    local current_index
    for index, destination in ipairs(route) do
        if destination.surface_name == current.surface_name then
            current_index = index
            break
        end
    end
    local start = current_index and current_index + 1 or 1
    for offset = 0, #route - 1 do
        local index = ((start + offset - 1) % #route) + 1
        local destination = route[index]
        if destination.surface_name ~= current.surface_name then
            return destination
        end
    end
end

function M.update(player, hud)
    hud = hud or player.gui.top.un_hud_flow
    local button = hud and hud.valid and hud[M.name]
    if not (button and button.valid) then return end
    local current, err = context(player)
    local destination = current and next_destination(player, current)
    button.enabled = destination ~= nil
    button.caption = destination and {
        'un.hud-property-cycle-destination',
        destination.caption,
    } or {'un.hud-property-cycle-unavailable'}
    button.tooltip = destination and {'un.hud-property-cycle-tooltip'}
        or err == 'vehicle' and {'un.travel-in-vehicle'}
        or {'un.hud-property-cycle-disabled-location'}
end

function M.cycle(player)
    local current, err = context(player)
    if not current then
        M.update(player)
        return false, err == 'vehicle' and 'in-vehicle' or 'travel-restricted'
    end
    local destination = next_destination(player, current)
    if not destination then return false, 'travel-restricted' end
    if destination.kind == 'hospice' then
        return surfaces.to_hospice_entrance(
            player,
            current.home_planet,
            destination.floor,
            destination.entrance
        )
    end
    local surface = game.surfaces[destination.surface_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    return surfaces.to_property(player, surface)
end

return M
