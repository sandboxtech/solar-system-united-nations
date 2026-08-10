local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')

local M = {}

local function disable_logistic_robot_recipe(force)
    if not (force and force.valid) then return end
    local recipe = force.recipes['logistic-robot']
    if recipe and recipe.valid then recipe.enabled = false end
end

function M.apply(force)
    if not (force and force.valid) then return end
    for _, name in ipairs(config.faction_initial_recipes) do
        local recipe = force.recipes[name]
        if recipe and recipe.valid then recipe.enabled = true end
    end
    disable_logistic_robot_recipe(force)
end

function M.ensure()
    for _, entry in ipairs(factions.all()) do
        M.apply(entry.force)
    end
end

events.on(defines.events.on_research_finished, function(event)
    M.apply(event.research.force)
end)

return M
