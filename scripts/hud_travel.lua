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
    local planet_name = factions.of_player(player)
    if not planet_name then return nil, 'location' end
    local floor, hospice_planet = surfaces.hospice_floor(player.physical_surface)
    if hospice_planet == planet_name then
        return {kind = 'hospice', floor = floor, planet_name = planet_name}
    end
    local property = properties.on_surface(player.physical_surface)
    if property and property.owner_index == player.index
            and property.sample_planet == planet_name then
        return {
            kind = 'property',
            property = property,
            planet_name = planet_name,
        }
    end
    return nil, 'location'
end

function M.update(player, hud)
    hud = hud or player.gui.top.un_hud_flow
    local button = hud and hud.valid and hud[M.name]
    if not (button and button.valid) then return end
    local current, err = context(player)
    button.enabled = current ~= nil
    button.tooltip = current and {'un.hud-property-cycle-tooltip'}
        or err == 'vehicle' and {'un.travel-in-vehicle'}
        or {'un.hud-property-cycle-disabled-location'}
end

function M.cycle(player)
    local current, err = context(player)
    if not current then
        M.update(player)
        return false, err == 'vehicle' and 'in-vehicle' or 'travel-restricted'
    end
    local owned = owned_home_properties(player, current.planet_name)
    if current.kind == 'hospice' and current.floor == 1 then
        return surfaces.to_hospice_entrance(
            player, current.planet_name, 2, 'upper'
        )
    end
    if current.kind == 'hospice' then
        if owned[1] then
            return surfaces.to_property(
                player, game.surfaces[owned[1].surface_name]
            )
        end
        return surfaces.to_hospice_entrance(
            player, current.planet_name, 1, 'lower'
        )
    end
    for index, property in ipairs(owned) do
        if property.id == current.property.id and owned[index + 1] then
            return surfaces.to_property(
                player, game.surfaces[owned[index + 1].surface_name]
            )
        end
    end
    return surfaces.to_hospice_entrance(
        player, current.planet_name, 1, 'lower'
    )
end

return M
