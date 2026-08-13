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
M.science_conversion_notifications = true
M.science_offline_conversion_ticks = 10 * M.ticks_per_minute
M.science_offline_conversion_max_hours = 12
M.logistic_network_roboport_limit = 16
M.logistic_network_logistic_robot_limit = 512
M.science_pack_experience = {
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
local function property_build_type(spec)
    spec.base_width = spec.base_width or 32
    spec.width_per_level = spec.width_per_level or 2
    spec.height = spec.height or 32
    spec.height_per_level = spec.height_per_level or 0
    spec.max_width = spec.max_width or 256
    spec.max_height = spec.max_height or 256
    spec.initial_price_multiplier = spec.initial_price_multiplier or 1
    spec.base_decay_hours = spec.base_decay_hours or 10
    spec.decay_hours_per_level = spec.decay_hours_per_level or 1
    spec.base_lifetime_hours = spec.base_lifetime_hours or 100
    spec.lifetime_hours_per_level = spec.lifetime_hours_per_level or 1
    if spec.expandable == nil then spec.expandable = true end
    return spec
end
M.property_build_types = {
    property_build_type{
        pack = 'automation-science-pack',
        key = 'shelter',
        base_decay_hours = 2,
        decay_hours_per_level = 0.1,
        base_lifetime_hours = 10,
        lifetime_hours_per_level = 1,
    },
    property_build_type{
        pack = 'logistic-science-pack',
        key = 'cottage',
        initial_price_multiplier = 2,
        base_decay_hours = 6,
        decay_hours_per_level = 0.2,
        base_lifetime_hours = 30,
        lifetime_hours_per_level = 3,
    },
    property_build_type{
        pack = 'military-science-pack',
        key = 'secure-cottage',
        initial_price_multiplier = 10,
        base_decay_hours = 100,
        decay_hours_per_level = 10,
        crime_chance_multiplier = 0.1,
        fixed_layout = {
            fill_tile = 'tutorial-grid',
        },
    },
    property_build_type{
        pack = 'chemical-science-pack',
        key = 'shore-cottage',
        initial_price_multiplier = 3,
        terrain_planet = 'nauvis',
        special_areas = {
            {tile = 'water', left = -8, top = -10, right = 8, bottom = -8},
        },
    },
    property_build_type{
        pack = 'production-science-pack',
        key = 'rail-estate',
        base_width = 512,
        width_per_level = 2,
        max_width = 1024,
        height = 64,
        height_per_level = 1,
        max_height = 320,
        exact_dimensions = true,
        initial_price_multiplier = 4,
        fixed_layout = {
            fill_tile = 'out-of-map',
            railway_tile = 'tutorial-grid',
            railway_corridor_length = 384,
            railway_corridor_height = 8,
        },
    },
    property_build_type{
        pack = 'utility-science-pack',
        key = 'utility-grid',
        base_width = 128,
        width_per_level = 1,
        height = 128,
        height_per_level = 1,
        max_width = 1024,
        max_height = 1024,
        exact_dimensions = true,
        initial_price_multiplier = 5,
        fixed_layout = {
            fill_tile = 'out-of-map',
            chunk_grid_tile = 'tutorial-grid',
            chunk_size = 32,
            chunk_inner_size = 30,
            core_tile = 'tutorial-grid',
            core_size = 16,
        },
    },
    property_build_type{
        pack = 'space-science-pack',
        key = 'sky-cottage',
        expandable = false,
        base_width = 96,
        width_per_level = 3,
        height = 96,
        initial_price_multiplier = 3,
        fixed_layout = {
            fill_tile = 'empty-space',
            middle_tile = 'space-platform-foundation',
            middle_size = 16,
            core_tile = 'tutorial-grid',
            core_size = 8,
        },
        surface_property_overrides = {
            gravity = 0,
            pressure = 0,
            ['magnetic-field'] = 0,
            ['day-night-cycle'] = 0,
        },
    },
    property_build_type{
        pack = 'metallurgic-science-pack',
        key = 'lava-cottage',
        initial_price_multiplier = 6,
        terrain_planet = 'vulcanus',
        special_areas = {
            {tile = 'lava', left = -8, top = -10, right = 8, bottom = -8},
        },
    },
    property_build_type{
        pack = 'electromagnetic-science-pack',
        key = 'oil-cottage',
        initial_price_multiplier = 7,
        terrain_planet = 'fulgora',
        special_areas = {
            {
                tile = 'oil-ocean-deep',
                left = -8,
                top = -10,
                right = 8,
                bottom = -8,
            },
        },
    },
    property_build_type{
        pack = 'agricultural-science-pack',
        key = 'garden-cottage',
        initial_price_multiplier = 8,
        terrain_planet = 'gleba',
        special_areas = {
            {
                tile = 'natural-yumako-soil',
                left = -8,
                top = -12,
                right = 0,
                bottom = -4,
            },
            {
                tile = 'natural-jellynut-soil',
                left = 0,
                top = -12,
                right = 8,
                bottom = -4,
            },
        },
    },
    property_build_type{
        pack = 'cryogenic-science-pack',
        key = 'cryogenic-cottage',
        initial_price_multiplier = 12,
        base_decay_hours = 192,
        decay_hours_per_level = 2,
        base_lifetime_hours = 288,
        lifetime_hours_per_level = 24,
        terrain_planet = 'aquilo',
        crime_chance_multiplier = 10,
    },
}
M.property_lifecycle_ticks = M.ticks_per_minute
M.rental_property_default_width = 24
M.rental_property_default_height = 16
M.rental_property_decay_hours = 2
local function permanent_rentals(count)
    return {
        {
            count = count,
            width = M.rental_property_default_width,
            height = M.rental_property_default_height,
            decay_hours = M.rental_property_decay_hours,
            fixed_layout = {fill_tile = 'tutorial-grid'},
        },
    }
end
M.property_permanent_defaults_by_planet = {
    nauvis = permanent_rentals(10),
    vulcanus = permanent_rentals(3),
    gleba = permanent_rentals(3),
    fulgora = permanent_rentals(3),
    aquilo = permanent_rentals(3),
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
M.ship_height = 512
M.ship_home_planet = 'nauvis'
M.ship_lock_native_creation = true
M.ship_lifecycle_ticks = M.ticks_per_minute

return M
