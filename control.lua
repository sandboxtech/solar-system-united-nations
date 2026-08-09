local state = require('scripts.state')

-- Require-time registration is deterministic. Each engine event is registered
-- once through scripts.events, while feature modules add their own handlers.
require('scripts.diagnostics')

script.on_init(function()
    state.ensure()
end)

script.on_configuration_changed(function()
    state.ensure()
end)
