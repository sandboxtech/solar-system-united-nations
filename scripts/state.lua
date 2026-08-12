local config = require('config')

local M = {}

local function copy_item_list(source)
    local result = {}
    for _, item in ipairs(source or {}) do
        result[#result + 1] = {name = item.name, count = item.count}
    end
    return result
end

function M.ensure()
    if storage.players == nil then storage.players = {} end
    if storage.player_experience_by_name == nil then
        storage.player_experience_by_name = {}
    end
    if storage.properties == nil then storage.properties = {} end
    if storage.next_property_id == nil then storage.next_property_id = 1 end
    if storage.deleting_properties == nil then storage.deleting_properties = {} end
    if storage.property_revision == nil then storage.property_revision = 0 end
    if storage.ship_revision == nil then storage.ship_revision = 0 end
    if storage.planet_revision == nil then storage.planet_revision = 0 end
    if storage.faction_revision == nil then storage.faction_revision = 0 end
    if storage.player_roster_revision == nil then
        storage.player_roster_revision = 0
    end
    if storage.player_data_revision == nil then
        storage.player_data_revision = 0
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
    if storage.starter_resources == nil then
        storage.starter_resources = copy_item_list(config.starter_resources)
    end
    if storage.hospice_grid_versions == nil then storage.hospice_grid_versions = {} end
    if storage.respawn_hospice_planets == nil then
        storage.respawn_hospice_planets = {}
    end
    if storage.pending_faction_switches == nil then
        storage.pending_faction_switches = {}
    end
    if storage.suppress_foreign_join_notifications == nil then
        storage.suppress_foreign_join_notifications = {}
    end
    if storage.faction_diplomacy_friendly == nil then
        storage.faction_diplomacy_friendly = {}
    end
    if storage.faction_pair_relations == nil then
        storage.faction_pair_relations = {}
    end
    if storage.faction_initial_technologies_granted == nil then
        storage.faction_initial_technologies_granted = {}
    end
    if storage.tech_leak_unlocked_forces == nil then
        storage.tech_leak_unlocked_forces = {}
    end
    if storage.ledger == nil then
        storage.ledger = {first_id = 1, next_id = 1, records = {}}
    end
    return storage
end

return M
