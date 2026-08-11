local config = require('config')
local playtime = require('scripts.playtime')
local state = require('scripts.state')

local M = {}

local DEFINITIONS = {
    initial_coin = {default = config.initial_credit, min = 0, max = 1000000000000, integer = true},
    friend_limit = {default = config.friend_limit, min = 0, max = 100, integer = true},
    ship_life_hours = {default = config.ship_life_hours, min = 1, max = 10000},
    faction_switch_min_online_hours = {
        default = config.faction_switch_min_online_hours,
        min = 0,
        max = 100000,
    },
    crime_min_online_hours = {
        default = config.crime_min_online_hours,
        min = 0,
        max = 100000,
    },
    ship_build_min_online_hours = {
        default = config.ship_build_min_online_hours,
        min = 0,
        max = 100000,
    },
    deconstruction_min_online_hours = {
        default = config.deconstruction_min_online_hours,
        min = 0,
        max = 100000,
    },
    cleanup_idle_hours = {default = config.player_cleanup_idle_hours, min = 1, max = 100000},
    planet_reset_min_hours = {
        default = config.public_planet_reset_min_hours,
        min = 0.1,
        max = 10000,
    },
    planet_reset_max_hours = {
        default = config.public_planet_reset_max_hours,
        min = 0.1,
        max = 10000,
    },
    planet_reset_exponent = {
        default = config.public_planet_reset_exponent,
        min = 0.01,
        max = 100,
    },
    faction_friendly_to_hostile_percent = {
        default = config.faction_friendly_to_hostile_chance * 100,
        min = 0,
        max = 100,
    },
    faction_hostile_to_friendly_percent = {
        default = config.faction_hostile_to_friendly_chance * 100,
        min = 0,
        max = 100,
    },
    property_tax_percent = {default = config.property_default_tax * 100, min = 0, max = 100},
    property_price_factor = {
        default = config.property_price_factor,
        min = 1,
        max = 100,
        exclusive_min = true,
        exclusive_max = true,
    },
    technology_price_multiplier = {
        default = config.technology_price_multiplier,
        min = 0.001,
        max = 1000,
    },
    spoil_time_modifier = {
        default = config.spoil_time_modifier,
        min = 0.001,
        max = 1000,
    },
    asteroid_spawning_rate = {
        default = config.asteroid_spawning_rate,
        min = 0,
        max = 1000,
    },
    property_limit_per_planet = {
        default = config.property_limit_per_planet,
        min = 0,
        max = 10000,
        integer = true,
    },
    property_build_price_multiplier = {
        default = config.property_build_price_per_experience,
        min = 0.001,
        max = 1000000,
    },
    property_salvage_percent = {
        default = config.property_salvage_percent,
        min = 0.01,
        max = 100,
    },
    tech_leak_interval_hours = {
        default = config.tech_leak_interval_hours,
        min = 0.1,
        max = 10000,
    },
    tech_leak_max_percent = {
        default = config.tech_leak_coefficient_max_percent,
        min = 0,
        max = 100,
    },
    tech_leak_max_affected = {
        default = config.tech_leak_max_affected,
        min = 0,
        max = 100000,
        integer = true,
    },
    planet_resets_enabled = {default = true, boolean = true},
    tech_leak_enabled = {default = true, boolean = true},
    admin_property_access = {default = false, boolean = true},
}

local function values()
    state.ensure()
    return storage.admin_settings
end

function M.get(key)
    local definition = DEFINITIONS[key]
    if not definition then return nil end
    local value = values()[key]
    if value == nil then return definition.default end
    return value
end

function M.set(key, value)
    local definition = DEFINITIONS[key]
    if not definition then return false, 'unknown-setting' end
    if definition.boolean then
        if type(value) ~= 'boolean' then return false, 'invalid-value' end
    else
        value = tonumber(value)
        if not value or value ~= value or value == math.huge
                or value == -math.huge then
            return false, 'invalid-value'
        end
        if definition.integer and value ~= math.floor(value) then
            return false, 'invalid-value'
        end
        if value < definition.min or value > definition.max
                or definition.exclusive_min and value == definition.min
                or definition.exclusive_max and value == definition.max then
            return false, 'out-of-range'
        end
    end
    if key == 'planet_reset_min_hours'
            and value > M.get('planet_reset_max_hours') then
        return false, 'out-of-range'
    end
    if key == 'planet_reset_max_hours'
            and value < M.get('planet_reset_min_hours') then
        return false, 'out-of-range'
    end
    values()[key] = value
    return true, value
end

function M.definition(key)
    return DEFINITIONS[key]
end

function M.online_requirement_left_ticks(player, key)
    if not (player and player.valid) then return math.huge end
    local required_ticks = M.get(key) * config.ticks_per_hour
    return math.max(0, math.ceil(required_ticks - playtime.ticks(player)))
end

function M.online_requirement_met(player, key)
    return M.online_requirement_left_ticks(player, key) <= 0
end

return M
