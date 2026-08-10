local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')
local initial_technologies = require('scripts.initial_technologies')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local state = require('scripts.state')

local M = {}

local function default_immune_technologies()
    local result = {}
    for _, name in ipairs(config.tech_leak_immune_technologies or {}) do
        result[name] = true
    end
    return result
end

local function immune_technologies()
    state.ensure()
    if type(storage.tech_leak_immune_technologies) ~= 'table' then
        storage.tech_leak_immune_technologies = default_immune_technologies()
    end
    return storage.tech_leak_immune_technologies
end

local function interval_ticks()
    return math.max(
        config.ticks_per_minute,
        math.floor(settings.get('tech_leak_interval_hours')
            * config.ticks_per_hour + 0.5)
    )
end

local function pack_count(technology)
    local seen = {}
    local count = 0
    for _, ingredient in pairs(technology.research_unit_ingredients or {}) do
        if not seen[ingredient.name] then
            seen[ingredient.name] = true
            count = count + 1
        end
    end
    return count
end

local function can_downgrade(technology)
    local base_level = technology.prototype.level or 1
    return technology.level > base_level
end

local function protected_prerequisites(force)
    local protected = {}
    local current = force.current_research
    if not (current and current.valid) then return protected end
    for _, prerequisite in pairs(current.prerequisites or {}) do
        if prerequisite and prerequisite.valid then
            protected[prerequisite.name] = true
        end
    end
    return protected
end

local function sorted_technology_names(force)
    local names = {}
    for name in pairs(force.technologies) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function run_force(force)
    if not (force and force.valid) then return 0 end
    state.ensure()
    local unlock = force.technologies[config.tech_leak_unlock_technology]
    if unlock and unlock.researched then
        storage.tech_leak_unlocked_forces[force.name] = true
    end
    if not storage.tech_leak_unlocked_forces[force.name] then return 0 end
    local planet_name = factions.planet_of_force(force)
    local chance_multiplier = config.tech_leak_chance_multiplier_by_planet[
        planet_name
    ] or 1
    local coefficient = math.random()
        * settings.get('tech_leak_max_percent') * chance_multiplier
    local protected = protected_prerequisites(force)
    local immune = immune_technologies()
    local lost = {}
    local downgraded = {}
    local affected_limit = settings.get('tech_leak_max_affected')
    local hits = {}

    for _, name in ipairs(sorted_technology_names(force)) do
        local technology = force.technologies[name]
        local prototype = technology.prototype
        local eligible = not immune[name]
            and not protected[name]
            and not prototype.research_trigger
            and (technology.researched or can_downgrade(technology))
        if eligible then
            local chance = math.min(1, coefficient * pack_count(technology) / 100)
            if chance > 0 and math.random() < chance then
                hits[#hits + 1] = name
            end
        end
    end

    local affected = math.min(affected_limit, #hits)
    for index = 1, affected do
        local chosen = math.random(index, #hits)
        hits[index], hits[chosen] = hits[chosen], hits[index]
    end
    for index = 1, affected do
        local name = hits[index]
        local technology = force.technologies[name]
        local icon = '[technology=' .. name .. ']'
        if can_downgrade(technology) then
            technology.level = technology.level - 1
            downgraded[#downgraded + 1] = icon .. ' Lv.' .. technology.level
        else
            technology.researched = false
            lost[#lost + 1] = icon
        end
    end
    table.sort(lost)
    table.sort(downgraded)

    if #lost > 0 then
        force.print({
            'un.tech-leak-lost',
            #lost,
            table.concat(lost, ' '),
        })
    end
    if #downgraded > 0 then
        force.print({
            'un.tech-leak-downgraded',
            #downgraded,
            table.concat(downgraded, ' '),
        })
    end
    initial_technologies.ensure_recipes(force)
    return #lost + #downgraded
end

function M.run()
    local total = 0
    for _, entry in ipairs(factions.all()) do
        total = total + run_force(entry.force)
    end
    return total
end

function M.ensure()
    state.ensure()
    for _, entry in ipairs(factions.all()) do
        local technology = entry.force.technologies[
            config.tech_leak_unlock_technology
        ]
        if technology and technology.researched then
            storage.tech_leak_unlocked_forces[entry.force.name] = true
        end
    end
    if not settings.get('tech_leak_enabled') then
        storage.tech_leak_next_tick = nil
        return
    end
    if storage.tech_leak_next_tick == nil then
        storage.tech_leak_next_tick = game.tick + interval_ticks()
    end
end

function M.reschedule()
    storage.tech_leak_next_tick = settings.get('tech_leak_enabled')
        and game.tick + interval_ticks() or nil
end

function M.apply_enabled(enabled)
    storage.tech_leak_next_tick = enabled
        and game.tick + interval_ticks() or nil
end

function M.left_ticks()
    if not settings.get('tech_leak_enabled') then return nil end
    M.ensure()
    return math.max(0, storage.tech_leak_next_tick - game.tick)
end

local function check()
    if not settings.get('tech_leak_enabled') then return end
    M.ensure()
    if game.tick < storage.tech_leak_next_tick then return end
    M.run()
    storage.tech_leak_next_tick = game.tick + interval_ticks()
end

scheduler.every(config.ticks_per_minute, check)

events.on(defines.events.on_research_finished, function(event)
    if event.research.name ~= config.tech_leak_unlock_technology then return end
    state.ensure()
    storage.tech_leak_unlocked_forces[event.research.force.name] = true
end)

return M
