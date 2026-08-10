local config = require('config')
local factions = require('scripts.factions')
local state = require('scripts.state')

local M = {}

local function sorted_unique_names(...)
    local seen = {}
    local result = {}
    for index = 1, select('#', ...) do
        for _, name in ipairs(select(index, ...) or {}) do
            if not seen[name] then
                seen[name] = true
                result[#result + 1] = name
            end
        end
    end
    table.sort(result)
    return result
end

local function research(force, name)
    local technology = force.technologies[name]
    if technology and technology.valid then
        technology.enabled = true
        technology.researched = true
    end
end

local function research_recursively(force, roots)
    local seen = {}
    local function visit(name)
        if seen[name] then return end
        seen[name] = true
        local technology = force.technologies[name]
        if not (technology and technology.valid) then return end
        local prerequisites = {}
        for prerequisite_name in pairs(technology.prerequisites or {}) do
            prerequisites[#prerequisites + 1] = prerequisite_name
        end
        table.sort(prerequisites)
        for _, prerequisite_name in ipairs(prerequisites) do
            visit(prerequisite_name)
        end
        research(force, name)
    end
    for _, name in ipairs(roots) do visit(name) end
end

local function grant(force, planet_name)
    local direct = sorted_unique_names(
        config.faction_initial_technologies,
        config.faction_initial_technologies_by_planet[planet_name]
    )
    local recursive = sorted_unique_names(
        config.faction_initial_technologies_recursive,
        config.faction_initial_technologies_recursive_by_planet[planet_name]
    )
    for _, name in ipairs(direct) do research(force, name) end
    research_recursively(force, recursive)
end

local function grant_recipes(force)
    for _, name in ipairs(config.faction_initial_recipes or {}) do
        local recipe = force.recipes[name]
        if recipe and recipe.valid then recipe.enabled = true end
    end
end

function M.ensure()
    state.ensure()
    for _, entry in ipairs(factions.all()) do
        if not storage.faction_initial_technologies_granted[entry.force.name] then
            grant(entry.force, entry.planet_name)
            storage.faction_initial_technologies_granted[entry.force.name] = true
        end
        if not storage.faction_initial_recipes_granted[entry.force.name] then
            grant_recipes(entry.force)
            storage.faction_initial_recipes_granted[entry.force.name] = true
        end
    end
end

return M
