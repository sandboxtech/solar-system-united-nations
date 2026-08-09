local gui = require('scripts.gui')
local properties = require('scripts.properties')
local restrictions = require('scripts.restrictions')
local ships = require('scripts.ships')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

function M.run()
    state.ensure()
    surfaces.ensure_hospice()
    properties.ensure_defaults()
    restrictions.ensure()
    ships.ensure()
    gui.ensure_all()
end

return M
