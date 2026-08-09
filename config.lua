local M = {}

M.schema_version = 1

M.ticks_per_second = 60
M.ticks_per_minute = 60 * M.ticks_per_second
M.ticks_per_hour = 60 * M.ticks_per_minute

M.space_age_mod_name = 'space-age'
M.linked_chest_name = 'linked-chest'
M.public_planets = {'nauvis', 'vulcanus', 'gleba', 'fulgora', 'aquilo'}

M.property_decay_ticks = 2 * M.ticks_per_hour
M.property_max_future_ticks = 30 * M.ticks_per_hour
M.property_price_cap = 1000000000

-- Stage 0 uses an isolated surface and reserved link IDs. Player link IDs start
-- at their positive player index, so these high IDs will not collide in normal
-- operation.
M.stage0_surface_name = 'un-stage0-lab'
M.stage0_link_id_a = 4294967295
M.stage0_link_id_b = 4294967294

return M
