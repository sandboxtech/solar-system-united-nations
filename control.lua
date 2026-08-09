-- Require-time registration is deterministic. Each engine event is registered
-- once through scripts.events, while feature modules add their own handlers.
require('scripts.diagnostics')
require('scripts.economy')
require('scripts.linked_inventory')
require('scripts.properties')
require('scripts.restrictions')
require('scripts.social')
require('scripts.ships')
require('scripts.disasters')
require('scripts.player_cleanup')
require('scripts.gui')

local bootstrap = require('scripts.bootstrap')

script.on_init(function()
    bootstrap.run()
end)

script.on_configuration_changed(function()
    bootstrap.run()
end)
