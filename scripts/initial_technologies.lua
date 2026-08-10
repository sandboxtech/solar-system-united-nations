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
    for _, name in ipairs(recursive) do
        local technology = force.technologies[name]
        if technology and technology.valid then
            technology.enabled = true
            technology.research_recursive()
        end
    end
end

local function grant_recipes(force)
    for _, name in ipairs(config.faction_initial_recipes or {}) do
        local recipe = force.recipes[name]
        if recipe and recipe.valid then recipe.enabled = true end
    end
end

function M.ensure_recipes(force)
    if force and force.valid then grant_recipes(force) end
end

function M.ensure()
    state.ensure()
    for _, entry in ipairs(factions.all()) do
        if not storage.faction_initial_technologies_granted[entry.force.name] then
            grant(entry.force, entry.planet_name)
            storage.faction_initial_technologies_granted[entry.force.name] = true
        end
        grant_recipes(entry.force)
    end
end

return M
