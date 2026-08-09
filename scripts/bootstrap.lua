local gui = require('scripts.gui')
local properties = require('scripts.properties')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

function M.run()
    state.ensure()
    surfaces.ensure_hospice()
    properties.ensure_defaults()
    gui.ensure_all()
end

return M
