local config = require('config')

local M = {}

function M.ensure()
    local old_version = storage.schema_version or 0
    if storage.players == nil then storage.players = {} end
    if storage.properties == nil then storage.properties = {} end
    if storage.next_property_id == nil then storage.next_property_id = 1 end
    if storage.deleting_properties == nil then storage.deleting_properties = {} end
    if storage.property_delete_confirm == nil then storage.property_delete_confirm = {} end
    if storage.property_revision == nil then storage.property_revision = 0 end
    if storage.property_supply == nil then
        storage.property_supply = {expand_checks = 0, contract_checks = 0}
    end
    if storage.property_name_translation_requests == nil then
        storage.property_name_translation_requests = {}
    end
    if storage.dropoffs == nil then storage.dropoffs = {} end
    if storage.ships == nil then storage.ships = {} end
    if storage.public_planet_resets == nil then
        storage.public_planet_resets = {}
    end
    if storage.admin_settings == nil then storage.admin_settings = {} end
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
