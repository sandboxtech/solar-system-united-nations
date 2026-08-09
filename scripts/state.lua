local config = require('config')

local M = {}

function M.ensure()
    local old_version = storage.schema_version or 0
    if storage.players == nil then storage.players = {} end
    if storage.properties == nil then storage.properties = {} end
    if storage.dropoffs == nil then storage.dropoffs = {} end
    if storage.stage0 == nil then storage.stage0 = {} end
    if storage.ledger == nil then
        storage.ledger = {first_id = 1, next_id = 1, records = {}}
    else
        if storage.ledger.first_id == nil then storage.ledger.first_id = 1 end
        if storage.ledger.next_id == nil then storage.ledger.next_id = 1 end
        if storage.ledger.records == nil then storage.ledger.records = {} end
    end
    if old_version < config.schema_version then
        storage.schema_version = config.schema_version
    end
    return storage
end

return M
