local M = {}

M.ticks_per_second = 60
M.ticks_per_minute = 60 * M.ticks_per_second
M.ticks_per_hour = 60 * M.ticks_per_minute

M.space_age_mod_name = 'space-age'
M.linked_chest_name = 'linked-chest'
M.faction_initial_technologies = {
    -- Generic trigger technologies.
    'steam-power',
    'electronics',
    'automation-science-pack',
    'steel-axe',
    'oil-processing',
    -- 'uranium-processing',
    'space-platform',
    'space-science-pack',
}
M.faction_initial_technologies_by_planet = {
    -- Nauvis is the default location and has no planet-discovery-nauvis
    -- technology prototype.
    nauvis = {},
    vulcanus = {
        'planet-discovery-vulcanus',
        'calcite-processing',
        'tungsten-carbide',
        'big-mining-drill',
        'foundry',
        'tungsten-steel',
        'metallurgic-science-pack',
    },
    gleba = {
        'planet-discovery-gleba',
        'agriculture',
        'heating-tower',
        'yumako',
        'biochamber',
        'jellynut',
        'bioflux',
        'artificial-soil',
        'bacteria-cultivation',
        'bioflux-processing',
        'agricultural-science-pack',
        -- 'biter-egg-handling',
    },
    fulgora = {
        'planet-discovery-fulgora',
        'recycling',
        'holmium-processing',
        'electromagnetic-plant',
        'electromagnetic-science-pack',
    },
    aquilo = {
        'planet-discovery-aquilo',
        'heating-tower',
        'lithium-processing',
        'cryogenic-plant',
        'cryogenic-science-pack',
    },
}
M.faction_initial_technologies_recursive = {
    'landfill',
    'solar-energy',
    'electric-engine',
    'electric-energy-accumulators',
}
M.faction_initial_technologies_recursive_by_planet = {
    nauvis = {},
    vulcanus = {
    },
    gleba = {
    },
    fulgora = {
    },
    aquilo = {
        'cryogenic-science-pack',
    },
}
M.faction_initial_recipes = {
    'ice-melting',
    'loader',
    'fast-loader',
    'express-loader',
    'turbo-loader',
}
M.tech_leak_immune_technologies = {
    'logistic-robotics',
    'space-platform-thruster',
    'planet-discovery-vulcanus',
    'planet-discovery-gleba',
    'planet-discovery-fulgora',
    'planet-discovery-aquilo',
}
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
M.public_planet_arrival_radius = 128
M.public_planet_reset_min_hours = 0.5
M.public_planet_reset_max_hours = 2.5
M.public_planet_reset_exponent = 2
M.public_planet_warning_minutes = {5}
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

M.initial_credit = 10000
M.ubi_credit_per_second = 1
M.ubi_max_seconds = 108000
M.ledger_record_limit = 2000
M.transfer_min_amount = 1000
M.transfer_fee_rate = 0.001
M.transfer_min_fee = 100
M.gui_refresh_ticks = M.ticks_per_second
M.gui_list_refresh_ticks = 5 * M.ticks_per_second
M.friend_limit = 10

M.starter_resources = {
    {name = 'iron-plate', count = 500},
    {name = 'copper-plate', count = 200},
    {name = 'stone', count = 100},
    {name = 'wood', count = 100},
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
M.tech_leak_interval_hours = 1
M.tech_leak_coefficient_max_percent = 0.25
M.tech_leak_max_affected = 5
M.tech_leak_unlock_technology = M.faction_diplomacy_technology
M.tech_leak_chance_multiplier_by_planet = {
    nauvis = 1,
    vulcanus = 1,
    gleba = 1,
    fulgora = 1,
    aquilo = 0.001,
}

M.wooden_chest_name = 'wooden-chest'
M.science_conversion_ticks = M.ticks_per_minute
M.logistic_network_roboport_limit = 16
M.logistic_network_logistic_robot_limit = 512
M.science_pack_credit = {
    ['automation-science-pack'] = 1,
    ['logistic-science-pack'] = 1,
    ['military-science-pack'] = 1,
    ['chemical-science-pack'] = 1,
    ['production-science-pack'] = 1,
    ['utility-science-pack'] = 1,
    ['space-science-pack'] = 1,
    ['metallurgic-science-pack'] = 1,
    ['agricultural-science-pack'] = 1,
    ['electromagnetic-science-pack'] = 1,
    ['cryogenic-science-pack'] = 1,
    ['promethium-science-pack'] = 1,
}
M.science_pack_order = {
    'automation-science-pack',
    'logistic-science-pack',
    'military-science-pack',
    'chemical-science-pack',
    'production-science-pack',
    'utility-science-pack',
    'space-science-pack',
    'metallurgic-science-pack',
    'agricultural-science-pack',
    'electromagnetic-science-pack',
    'cryogenic-science-pack',
    'promethium-science-pack',
}

M.hospice_surface_prefix = 'un-hospice-'
M.hospice_surface_width = 128
M.hospice_surface_height = 64
M.hospice_core_size = 32
M.hospice_liquid_border_width = 2
M.hospice_tile_layout_version = 4
M.hospice_tiles = {
    nauvis = {land = 'grass-1', liquid = 'water'},
    vulcanus = {land = 'volcanic-ash-soil', liquid = 'lava'},
    gleba = {land = 'highland-yellow-rock', liquid = 'wetland-blue-slime'},
    fulgora = {land = 'fulgoran-dunes', liquid = 'oil-ocean-deep'},
    aquilo = {land = 'dust-lumpy', liquid = 'ammoniacal-ocean'},
}
M.property_surface_prefix = 'un-property-'
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
M.property_max_size = 256
M.property_name_max_characters = 64
M.property_name_max_bytes = 256
M.property_salvage_percent = 20
M.property_sample_planets = M.public_planets
M.property_initial_price_min = 1000
M.property_initial_price_max = 3000
M.property_build_stamina_cost = 50000
M.property_build_price_per_experience = 10
M.property_build_experience_base = 1000
M.property_build_experience_per_level = 100
M.property_build_types = {
    {
        pack = 'automation-science-pack',
        key = 'shelter',
        base_width = 32,
        height = 32,
        base_decay_hours = 6,
        decay_hours_per_level = 0.1,
        base_lifetime_hours = 12,
        lifetime_hours_per_level = 1,
    },
    {
        pack = 'logistic-science-pack',
        key = 'cottage',
        base_width = 32,
        height = 32,
        base_decay_hours = 12,
        decay_hours_per_level = 0.2,
        base_lifetime_hours = 24,
        lifetime_hours_per_level = 1,
    },
}
M.property_lifecycle_ticks = M.ticks_per_minute
M.property_permanent_defaults = {
    {count = 1, width = 64, height = 32, decay_hours = 3},
    {count = 1, width = 128, height = 64, decay_hours = 3},
    {count = 1, width = 256, height = 128, decay_hours = 3},
}

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
M.ship_height = 128
M.ship_home_planet = 'nauvis'
M.ship_lock_native_creation = true
M.ship_lifecycle_ticks = M.ticks_per_minute

return M
