local config = require('config')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')

local M = {}
local TUTORIAL_GRID_NAME = 'tutorial-grid'
local public_planets = {}
for _, name in ipairs(config.public_planets) do public_planets[name] = true end

local function map_gen_settings(width, height)
    return {
        width = width,
        height = height or width,
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

local function apply_property_tiles(surface, half_width, half_height, has_water)
    local tiles = {}
    local margin = config.property_water_margin
    for y = -half_height, half_height - 1 do
        for x = -half_width, half_width - 1 do
            local water = has_water and (
                x < -half_width + margin or x >= half_width - margin
                or y < -half_height + margin or y >= half_height - margin
            )
            tiles[#tiles + 1] = {
                name = water and 'water' or TUTORIAL_GRID_NAME,
                position = {x, y},
            }
        end
    end
    surface.set_tiles(tiles, false, false, true, false)
end

local function apply_tutorial_grid(surface, half_size)
    apply_property_tiles(surface, half_size, half_size, false)
end

function M.ensure_hospice()
    local surface = game.surfaces[config.hospice_surface_name]
    if not (surface and surface.valid) then
        surface = game.create_surface(
            config.hospice_surface_name,
            map_gen_settings(config.hospice_surface_size)
        )
    else
        local settings = surface.map_gen_settings
        settings.width = config.hospice_surface_size
        settings.height = config.hospice_surface_size
        surface.map_gen_settings = settings
    end
    ensure_generated(surface, 1)
    if storage.hospice_grid_version ~= 1 then
        apply_tutorial_grid(surface, config.hospice_surface_size / 2)
        storage.hospice_grid_version = 1
    end
    surface.localised_name = {'un.hospice-name'}
    game.forces.player.set_spawn_position({0, 0}, surface)
    return surface
end

function M.create_property_surface(property_id, spec)
    local n = spec.n
    local half_width = spec.shape == 'long' and 2 * n or n
    local half_height = n
    local width = 2 * half_width
    local height = 2 * half_height
    local name = config.property_surface_prefix .. tostring(property_id)
    local surface = game.surfaces[name]
    if not (surface and surface.valid) then
        surface = game.create_surface(name, map_gen_settings(width, height))
    end
    ensure_generated(surface, math.max(1, math.ceil(math.max(width, height) / 64)))
    apply_property_tiles(surface, half_width, half_height, spec.water == true)
    surface.solar_power_multiplier = spec.solar
    surface.localised_name = spec.name or {'un.property-default-name', property_id}
    game.forces.player.set_spawn_position({0, 0}, surface)
    game.forces.player.chart(surface, {
        {-half_width, -half_height},
        {half_width, half_height},
    })
    return surface, half_width, half_height
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
    local source = player.physical_surface
    if not (source and source.valid and source.name == 'nauvis') then
        return false, 'travel-restricted'
    end
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.to_hospice(player)
    return M.teleport(player, M.ensure_hospice())
end

function M.to_planet(player)
    local source = player.physical_surface
    if not (source and source.valid) then return false, 'travel-restricted' end
    if source and public_planets[source.name] and source.name ~= 'nauvis' then
        return false, 'travel-restricted'
    end
    local dropoff = linked_inventory.get_active_dropoff(player.index)
    if dropoff then
        return M.teleport_near(player, dropoff.surface, dropoff.position, false)
    end

    local surface = game.surfaces.nauvis
    if not (surface and surface.valid) then return false, 'surface-missing' end
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.suicide(player)
    local character = player.character
    if not (character and character.valid) then
        for _, candidate in pairs(player.get_associated_characters()) do
            if candidate.valid then character = candidate; break end
        end
    end
    if not (character and character.valid) then return false, 'no-character' end
    return character.die(game.forces.neutral)
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
