local M = {}

M.ticks_per_second = 60
M.ticks_per_minute = 60 * M.ticks_per_second
M.ticks_per_hour = 60 * M.ticks_per_minute

M.space_age_mod_name = 'space-age'
M.linked_chest_name = 'linked-chest'
M.personal_linked_chest_limit = 1
M.personal_linked_chest_home_planet_only = true
M.personal_linked_chest_allow_hospice = true
M.personal_linked_chest_allow_property = true
M.faction_chat_colors = {
    nauvis = '0.35,0.70,1.00',
    vulcanus = '1.00,0.45,0.25',
    gleba = '0.55,0.90,0.35',
    fulgora = '0.85,0.55,1.00',
    aquilo = '0.45,0.90,1.00',
}
M.public_planets = {'nauvis', 'vulcanus', 'gleba', 'fulgora', 'aquilo'}
M.faction_force_prefix = 'un-faction-'
M.faction_diplomacy_technology = 'space-platform-thruster'
M.faction_friendly_to_hostile_chance = 0.2
M.faction_hostile_to_friendly_chance = 0.9
require('config.technologies')(M)
M.public_planet_arrival_radius = 128
M.public_planet_reset_min_hours = 0.5
M.public_planet_reset_max_hours = 2.5
M.public_planet_reset_exponent = 2
M.public_planet_foreign_warning_early_minutes = 5
M.public_planet_foreign_warning_final_minutes = 1
M.public_planet_check_ticks = 60 * 60
M.public_planet_solar_factors = {0.75, 1, 1.25}
M.public_planet_day_factors = {0.75, 1, 1.5}
M.public_planet_resource_base = {frequency = 2, size = 2, richness = 0.25}
M.public_planet_resource_spread = 1
M.public_planet_terrain_spread = 1
M.public_planet_cliff_spread = 1
M.public_planet_enemy_spread = 2
M.public_planet_starting_area_spread = 0.5
M.public_planet_peaceful_chance = 0.01
M.planet_reset_acceleration_stamina_cost = 1000
M.planet_reset_acceleration_fraction = 0.1
M.planet_reset_acceleration_min_remaining_minutes = 8
M.technology_price_multiplier = 2
M.spoil_time_modifier = 1
M.asteroid_spawning_rate = 1

M.player_cleanup_idle_hours = 90
M.player_cleanup_check_ticks = 60 * 60 * 60
M.player_cleanup_admins = false

M.property_price_cap = 1000000000
M.property_price_factor = 2
M.property_self_purchase_tax_multiplier = 0.5

M.initial_credit = 10000
M.ubi_credit_per_second = 1
M.ubi_max_seconds = 108000
M.ledger_record_limit = 2000
M.transfer_min_amount = 1000
M.transfer_fee_rate = 0.001
M.transfer_min_fee = 100
require('config.market')(M)
M.gui_refresh_ticks = M.ticks_per_second
-- Large lists use revisions for immediate structural changes. This slower
-- fallback only refreshes values which naturally change with elapsed time.
M.gui_list_refresh_ticks = M.ticks_per_minute
M.friend_limit = 10

M.starter_resources = {
    {name = 'iron-plate', count = 500},
    {name = 'copper-plate', count = 200},
    {name = 'stone', count = 100},
    {name = 'wood', count = 100},
    {name = 'automation-science-pack', count = 2000},
    {name = 'military-science-pack', count = 2000},
}
M.starter_kit_stamina_cost = 10000
M.starter_kit_armor = 'modular-armor'
M.starter_kit_equipment = {
    {name = 'personal-roboport-equipment', count = 1},
    {name = 'solar-panel-equipment', count = 6},
}
M.starter_kit_items = {
    {name = 'construction-robot', count = 5},
}
M.wood_supply_count = 100
M.wood_supply_stamina_cost = 1000

M.property_limit_per_planet = 100
M.wooden_chest_name = 'wooden-chest'
M.science_conversion_ticks = M.ticks_per_minute
M.science_conversion_notifications = true
M.science_offline_conversion_ticks = 10 * M.ticks_per_minute
M.science_offline_conversion_max_hours = 12
M.logistic_network_roboport_limit = 16
M.logistic_network_logistic_robot_limit = 512
M.hospice_surface_prefix = 'un-hospice-'
M.hospice_surface_width = 128
M.hospice_surface_height = 128
M.hospice_property_level = 192
M.hospice_tile_layout_version = 7
M.property_surface_prefix = 'un-property-'
M.surface_hidden_from_foreign_factions = false
M.surface_hidden_from_home_faction = false
M.property_default_tax = 0.10
M.property_solar_multiplier = 0.10
M.property_min_brightness = 0.05
M.property_daytime_parameters = {
    dusk = 0.25,
    evening = 0.45,
    morning = 0.55,
    dawn = 0.75,
}
M.property_link_id_unowned = 0
M.property_entity_layout_version = 3
M.property_linked_chest_positions = {
    {x = 0, y = 3},
    {x = 1, y = 3},
    {x = -1, y = 3},
    {x = -2, y = 3},
}
M.property_linked_loader_name = 'turbo-loader'
M.property_linked_loader_offset = {x = 0, y = -1}
M.faction_logistics_link_id_base = 4000000000
M.faction_logistics_station_name = 'cargo-landing-pad'
-- Keep the 8x8 landing-pad collision box clear of chests centred on y=0.
M.faction_logistics_station_position = {x = 0, y = -5}
M.faction_logistics_chest_positions = {
    {x = -2, y = 0},
    {x = -1, y = 0},
    {x = 0, y = 0},
    {x = 1, y = 0},
}
M.faction_logistics_loader_offset = {x = 0, y = 1}
M.faction_logistics_hospice_chest_positions = {
    {x = -2, y = 0},
    {x = -1, y = 0},
    {x = 0, y = 0},
    {x = 1, y = 0},
}
M.faction_logistics_hospice_loader_offset = {x = 0, y = -1}
M.property_max_size = 1024
M.property_name_max_characters = 64
M.property_name_max_bytes = 256
M.property_salvage_percent = 20
M.property_sample_planets = M.public_planets
M.property_initial_price_min = 1000
M.property_initial_price_max = 3000
M.property_build_stamina_cost = 50000
M.property_build_price_per_experience = 10
M.property_build_experience_base = 2000
M.property_build_experience_per_level = 200
M.property_renew_experience_multiplier = 1
M.property_renew_stamina_base_cost = 1000
M.property_renew_stamina_multiplier = 1
M.property_expansion_experience_multiplier = 2
M.property_expansion_stamina_cost = 50000
M.property_lifecycle_ticks = M.ticks_per_minute
M.admin_experience_grant = 1000000
M.blueprint_max_entities = 16384
M.blueprint_max_tiles = 4096
M.blueprint_max_span = 256
M.rental_property_default_width = 24
M.rental_property_default_height = 16
M.rental_property_decay_hours = 6
M.rental_property_fixed_layout = {fill_tile = 'tutorial-grid'}
M.rental_property_layout_anchor_up = true
require('config.property_types')(M)

M.stamina_max = 108000
M.stamina_per_second = 1
M.suicide_stamina_cost = 10000
M.fast_respawn_stamina_cost = 1000
M.fast_respawn_seconds = 10
M.normal_respawn_seconds = 60

M.ship_life_hours = 12
M.ship_stamina_cost = 10000
M.crime_coin_cost = 1000
M.crime_stamina_cost = 10000
M.crime_price_scale = 10000
M.faction_switch_min_online_hours = 1
M.crime_min_online_hours = 1
M.ship_build_min_online_hours = 1
M.deconstruction_min_online_hours = 1
M.ship_width_per_level = 2
M.ship_base_width = 16
M.ship_height = 512
M.ship_home_planet = 'nauvis'
M.ship_lock_native_creation = true
M.ship_lifecycle_ticks = M.ticks_per_minute

return M
