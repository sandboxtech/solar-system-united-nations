local M = {}

M.schema_version = 13

M.ticks_per_second = 60
M.ticks_per_minute = 60 * M.ticks_per_second
M.ticks_per_hour = 60 * M.ticks_per_minute

M.space_age_mod_name = 'space-age'
M.linked_chest_name = 'linked-chest'
M.public_planets = {'nauvis', 'vulcanus', 'gleba', 'fulgora', 'aquilo'}

M.property_decay_ticks = 2 * M.ticks_per_hour
M.property_max_future_ticks = 30 * M.ticks_per_hour
M.property_price_cap = 1000000000

M.initial_credit = 0
M.ubi_credit_per_second = 1
M.ubi_max_seconds = 100000
M.ledger_record_limit = 2000
M.gui_refresh_ticks = M.ticks_per_second

M.wooden_chest_name = 'wooden-chest'
M.science_conversion_ticks = M.ticks_per_minute
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
M.quality_credit_multiplier = {
    normal = 1,
    uncommon = 2,
    rare = 4,
    epic = 8,
    legendary = 16,
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

M.hospice_surface_name = 'un-hospice'
M.hospice_surface_size = 64
M.property_surface_prefix = 'un-property-'
M.property_default_tax = 0.10
M.property_link_id_unowned = 0
M.property_max_size = 128
M.property_sample_planets = {'nauvis', 'gleba'}
M.property_side_lengths = {32, 64, 128}
M.property_initial_price_min = 1000
M.property_initial_price_max = 2000
M.default_properties = {
    {solar = 0.1, sample_planet = 'nauvis'},
    {solar = 1, sample_planet = 'gleba'},
    {solar = 10, sample_planet = 'nauvis'},
    {solar = 0.1, sample_planet = 'gleba'},
    {solar = 1, sample_planet = 'nauvis'},
    {solar = 10, sample_planet = 'gleba'},
    {solar = 0.1, sample_planet = 'nauvis'},
    {solar = 1, sample_planet = 'gleba'},
    {solar = 10, sample_planet = 'nauvis'},
}

M.ship_life_hours = 50
M.ship_credit_cost = 1000
M.ship_width_per_level = 2
M.ship_base_width = 16
M.ship_height = 512
M.ship_home_planet = 'nauvis'
M.ship_lock_native_creation = true
M.ship_lifecycle_ticks = M.ticks_per_minute

-- Stage 0 uses an isolated surface and reserved link IDs. Player link IDs start
-- at their positive player index, so these high IDs will not collide in normal
-- operation.
M.stage0_surface_name = 'un-stage0-lab'
M.stage0_link_id_a = 4294967295
M.stage0_link_id_b = 4294967294

return M
