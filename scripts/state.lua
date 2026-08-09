local M = {}

function M.ensure()
    if storage.players == nil then storage.players = {} end
    if storage.properties == nil then storage.properties = {} end
    if storage.next_property_id == nil then storage.next_property_id = 1 end
    if storage.deleting_properties == nil then storage.deleting_properties = {} end
    if storage.property_revision == nil then storage.property_revision = 0 end
    if storage.property_name_translation_requests == nil then
        storage.property_name_translation_requests = {}
    end
    if storage.dropoffs == nil then storage.dropoffs = {} end
    if storage.ships == nil then storage.ships = {} end
    if storage.public_planet_resets == nil then
        storage.public_planet_resets = {}
    end
    if storage.admin_settings == nil then storage.admin_settings = {} end
    if storage.hospice_grid_versions == nil then storage.hospice_grid_versions = {} end
    if storage.respawn_hospice_planets == nil then
        storage.respawn_hospice_planets = {}
    end
    if storage.pending_faction_switches == nil then
        storage.pending_faction_switches = {}
    end
    if storage.stage0 == nil then storage.stage0 = {} end
    if storage.ledger == nil then
        storage.ledger = {first_id = 1, next_id = 1, records = {}}
    end
    return storage
end

return M
