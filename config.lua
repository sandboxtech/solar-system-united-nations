local M = {}

M.schema_version = 4

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

-- Stage 0 uses an isolated surface and reserved link IDs. Player link IDs start
-- at their positive player index, so these high IDs will not collide in normal
-- operation.
M.stage0_surface_name = 'un-stage0-lab'
M.stage0_link_id_a = 4294967295
M.stage0_link_id_b = 4294967294

return M
