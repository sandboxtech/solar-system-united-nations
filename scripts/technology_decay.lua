local config = require('config')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')

local M = {}

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

function M.run()
    local force = game.forces.player
    if not (force and force.valid) then return 0 end
    local coefficient = math.random()
        * settings.get('tech_leak_max_percent')
    local protected = protected_prerequisites(force)
    local lost = {}
    local downgraded = {}

    for _, name in ipairs(sorted_technology_names(force)) do
        local technology = force.technologies[name]
        local prototype = technology.prototype
        local eligible = not protected[name]
            and not prototype.research_trigger
            and (technology.researched or can_downgrade(technology))
        if eligible then
            local chance = math.min(1, coefficient * pack_count(technology) / 100)
            if chance > 0 and math.random() < chance then
                local icon = '[technology=' .. name .. ']'
                if can_downgrade(technology) then
                    technology.level = technology.level - 1
                    downgraded[#downgraded + 1] = icon
                        .. ' Lv.' .. technology.level
                else
                    technology.researched = false
                    lost[#lost + 1] = icon
                end
            end
        end
    end

    if #lost > 0 then
        game.print({
            'un.tech-leak-lost',
            #lost,
            table.concat(lost, ' '),
        })
    end
    if #downgraded > 0 then
        game.print({
            'un.tech-leak-downgraded',
            #downgraded,
            table.concat(downgraded, ' '),
        })
    end
    return #lost + #downgraded
end

function M.ensure()
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

scheduler.every(config.ticks_per_second, check)

return M
