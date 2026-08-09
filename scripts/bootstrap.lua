local config = require('config')
local gui = require('scripts.gui')
local properties = require('scripts.properties')
local restrictions = require('scripts.restrictions')
local ships = require('scripts.ships')
local disasters = require('scripts.disasters')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')
local technology_decay = require('scripts.technology_decay')

local M = {}

function M.run()
    state.ensure()
    for _, name in ipairs(config.public_planets) do
        surfaces.ensure_hospice(name)
    end
    disasters.ensure()
    technology_decay.ensure()
    properties.ensure()
    restrictions.ensure()
    ships.ensure()
    gui.ensure_all()
end

return M
