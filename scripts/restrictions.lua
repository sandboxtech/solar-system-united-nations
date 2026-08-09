local events = require('scripts.events')
local factions = require('scripts.factions')

local M = {}

local function disable_logistic_robot_recipe(force)
    if not (force and force.valid) then return end
    local recipe = force.recipes['logistic-robot']
    if recipe and recipe.valid then recipe.enabled = false end
end

function M.ensure()
    for _, entry in ipairs(factions.all()) do
        disable_logistic_robot_recipe(entry.force)
    end
end

events.on(defines.events.on_research_finished, function(event)
    disable_logistic_robot_recipe(event.research.force)
end)

return M
