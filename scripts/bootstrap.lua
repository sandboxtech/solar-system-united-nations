local gui = require('scripts.gui')
local state = require('scripts.state')

local M = {}

function M.run()
    state.ensure()
    gui.ensure_all()
end

return M
