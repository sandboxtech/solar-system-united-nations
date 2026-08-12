local config = require('config')
local economy = require('scripts.economy')
local factions = require('scripts.factions')
local properties = require('scripts.properties')
local settings = require('scripts.settings')
local stamina = require('scripts.stamina')
local surfaces = require('scripts.surfaces')

local M = {}

local function targets(planet_name, player_index)
    local result = {}
    for _, property in ipairs(properties.list(planet_name)) do
        local surface = game.surfaces[property.surface_name]
        if property.owner_index and property.owner_index ~= player_index
                and not properties.all_open(property.owner_index)
                and surface and surface.valid then
            result[#result + 1] = property
        end
    end
    return result
end

local function context(player)
    if not (player and player.valid) then return nil, 'invalid-player' end
    local surface = player.physical_surface
    if not (surface and surface.valid) then return nil, 'invalid-location' end
    if surface.platform then return nil, 'in-space' end
    if player.physical_vehicle and player.physical_vehicle.valid then
        return nil, 'in-vehicle'
    end
    if not surfaces.can_start_public_travel(surface) then
        return nil, 'invalid-location'
    end
    local planet_name = surfaces.context_planet(surface)
    if not planet_name then return nil, 'invalid-location' end
    return planet_name
end

function M.availability(player)
    if not (player and player.valid) then return false, 'invalid-player' end
    if not settings.get('crime_enabled') then return false, 'feature-disabled' end
    if not settings.online_requirement_met(player, 'crime_min_online_hours') then
        return false, 'crime-online-time'
    end
    local planet_name, err = context(player)
    if not planet_name then return false, err end
    local candidates = targets(planet_name, player.index)
    if #candidates == 0 then return false, 'no-targets', planet_name, 0 end
    if economy.get_balance(player.index) < config.crime_coin_cost then
        return false, 'insufficient-credit', planet_name, #candidates
    end
    if stamina.get(player.index) < config.crime_stamina_cost then
        return false, 'insufficient-stamina', planet_name, #candidates
    end
    return true, nil, planet_name, #candidates
end

local function chance_text(chance)
    local percent = chance * 100
    if percent >= 1 then return string.format('%.2f', percent) end
    return string.format('%.4f', percent)
end

function M.attempt(player)
    local available, err, planet_name = M.availability(player)
    if not available then return false, err end
    local candidates = targets(planet_name, player.index)
    if #candidates == 0 then return false, 'no-targets' end
    local property = candidates[math.random(#candidates)]
    local price = properties.current_price(property)
    local chance = math.min(1, (1 / (1 + price / config.crime_price_scale))
        * (tonumber(property.crime_chance_multiplier) or 1))

    if not stamina.spend(player.index, config.crime_stamina_cost) then
        return false, 'insufficient-stamina'
    end
    local paid, pay_err = economy.change(
        player.index,
        -config.crime_coin_cost,
        'crime-attempt'
    )
    if not paid then
        stamina.refund(player.index, config.crime_stamina_cost)
        return false, pay_err
    end

    local success = math.random() < chance
    if success then
        local surface = game.surfaces[property.surface_name]
        success = surface and surface.valid
            and surfaces.teleport(player, surface) == true
    end
    game.print({
        success and 'un.crime-broadcast-success'
            or 'un.crime-broadcast-failure',
        player.name,
        chance_text(chance),
        properties.surface_display_name(property),
        factions.display_name(factions.of_player(player)),
    })
    return true, success, property, chance
end

return M
