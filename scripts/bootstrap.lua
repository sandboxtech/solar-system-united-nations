local config = require('config')
local factions = require('scripts.factions')
local faction_logistics = require('scripts.faction_logistics')
local gui = require('scripts.gui')
local permissions = require('scripts.permissions')
local properties = require('scripts.properties')
local initial_technologies = require('scripts.initial_technologies')
local linked_inventory = require('scripts.linked_inventory')
local market = require('scripts.market')
local ships = require('scripts.ships')
local disasters = require('scripts.disasters')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')
local technology_decay = require('scripts.technology_decay')

local M = {}

local function run()
    state.ensure()
    factions.ensure()
    market.ensure()
    linked_inventory.ensure()
    for _, name in ipairs(config.public_planets) do
        surfaces.ensure_hospice(name, 1)
        surfaces.ensure_hospice(name, 2)
    end
    disasters.ensure()
    faction_logistics.ensure_all()
    surfaces.sync_all_hospice_environments()
    technology_decay.ensure()
    properties.ensure()
    permissions.ensure()
    initial_technologies.ensure()
    ships.ensure()
    surfaces.sync_all_property_environments()
    gui.ensure_all()
end

function M.run()
    run()
end

return M
