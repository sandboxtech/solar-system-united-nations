local config = require('config')

local M = {}

function M.ensure()
    if storage.schema_version == nil then
        storage.schema_version = config.schema_version
    end
    if storage.players == nil then storage.players = {} end
    if storage.properties == nil then storage.properties = {} end
    if storage.stage0 == nil then storage.stage0 = {} end
    return storage
end

return M
