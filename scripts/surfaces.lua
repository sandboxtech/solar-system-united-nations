local config = require('config')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')

local M = {}

local function map_gen_settings(size)
    return {
        width = size,
        height = size,
        water = 0,
        peaceful_mode = true,
        no_enemies_mode = true,
        default_enable_all_autoplace_controls = false,
        autoplace_settings = {
            entity = {treat_missing_as_default = false, settings = {}},
            decorative = {treat_missing_as_default = false, settings = {}},
        },
    }
end

local function ensure_generated(surface, radius)
    surface.request_to_generate_chunks({0, 0}, radius or 1)
    surface.force_generate_chunk_requests()
end

function M.ensure_hospice()
    local surface = game.surfaces[config.hospice_surface_name]
    if not (surface and surface.valid) then
        surface = game.create_surface(
            config.hospice_surface_name,
            map_gen_settings(config.hospice_surface_size)
        )
    end
    ensure_generated(surface, 1)
    surface.localised_name = {'un.hospice-name'}
    game.forces.player.set_spawn_position({0, 0}, surface)
    return surface
end

function M.create_property_surface(property_id, size)
    local name = config.property_surface_prefix .. tostring(property_id)
    local surface = game.surfaces[name]
    if not (surface and surface.valid) then
        surface = game.create_surface(name, map_gen_settings(size))
    end
    ensure_generated(surface, math.max(1, math.ceil(size / 64)))
    surface.localised_name = {'un.property-default-name', property_id}
    game.forces.player.set_spawn_position({0, 0}, surface)
    local half_size = size / 2
    game.forces.player.chart(surface, {
        {-half_size, -half_size},
        {half_size, half_size},
    })
    return surface
end

local function safe_position(surface, center)
    surface.request_to_generate_chunks(center, 1)
    surface.force_generate_chunk_requests()
    return surface.find_non_colliding_position('character', center, 64, 1)
end

function M.teleport_near(player, surface, center, allow_vehicle)
    if not (surface and surface.valid) then return false, 'surface-missing' end
    if not allow_vehicle and player.vehicle and player.vehicle.valid then
        return false, 'in-vehicle'
    end
    local position = safe_position(surface, center)
    if not position then return false, 'position-missing' end
    return player.teleport(position, surface)
end

function M.teleport(player, surface)
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.to_hospice(player)
    return M.teleport_near(player, M.ensure_hospice(), {0, 0}, false)
end

function M.to_planet(player)
    local dropoff = linked_inventory.get_active_dropoff(player.index)
    if dropoff then
        return M.teleport_near(player, dropoff.surface, dropoff.position, false)
    end

    local surface = game.surfaces.nauvis
    if not (surface and surface.valid) then return false, 'surface-missing' end
    return M.teleport_near(player, surface, {0, 0}, false)
end

local function respawn_destination(player)
    local dropoff = linked_inventory.get_active_dropoff(player.index)
    if dropoff then return dropoff.surface, dropoff.position end
    return M.ensure_hospice(), {0, 0}
end

events.on(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then M.to_hospice(player) end
end)

events.on(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local surface, center = respawn_destination(player)
    local ok, err = M.teleport_near(player, surface, center, true)
    if not ok then
        log('[un] failed to move respawned player ' .. player.index .. ': ' .. tostring(err))
    end
end)

return M
