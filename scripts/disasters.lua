local config = require('config')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

local STATISTIC_GETTERS = {
    'get_item_production_statistics',
    'get_fluid_production_statistics',
    'get_kill_count_statistics',
    'get_entity_build_count_statistics',
}

local function planet_label(name)
    return {'', '[planet=' .. name .. '] ', {'space-location-name.' .. name}}
end

local function ensure_surface(name)
    local surface = game.surfaces[name]
    if surface and surface.valid then return surface end
    local planet = game.planets[name]
    if not (planet and planet.valid) then return nil end
    return planet.create_surface()
end

local function period(name)
    return (config.public_planet_reset_hours[name] or 2)
        * config.ticks_per_hour
end

local function ensure_record(name)
    state.ensure()
    local records = storage.public_planet_resets
    local record = records[name]
    local surface = ensure_surface(name)
    if not record then
        local offset = (config.public_planet_initial_offset_minutes[name] or 0)
            * config.ticks_per_minute
        record = {
            state = 'open',
            round = 0,
            next_tick = game.tick + period(name) + offset,
            warned = {},
        }
        records[name] = record
    end
    if record.state == nil then record.state = 'open' end
    if record.round == nil then record.round = 0 end
    if record.warned == nil then record.warned = {} end
    if record.next_tick == nil and record.state == 'open'
            and settings.get('planet_resets_enabled') then
        record.next_tick = game.tick + period(name)
    end
    if surface and surface.valid then
        if record.base_solar == nil then
            record.base_solar = surface.solar_power_multiplier
        end
        if record.base_day == nil then record.base_day = surface.ticks_per_day end
    end
    return record, surface
end

local function evacuate_player(player, target_surface)
    if player.connected and player.surface == target_surface
            and player.physical_surface ~= target_surface then
        pcall(function() player.exit_remote_view() end)
    end
    if player.physical_surface == target_surface then
        local moved = false
        pcall(function()
            if player.connected then player.exit_remote_view() end
            if player.vehicle and player.vehicle.valid then player.driving = false end
            moved = surfaces.teleport_near(
                player,
                surfaces.ensure_hospice(),
                {0, 0},
                true
            )
        end)
        if not moved then
            local character = player.character
            if character and character.valid then
                pcall(function()
                    character.teleport({0, 2}, surfaces.ensure_hospice())
                end)
            end
        end
    end

    -- A player can retain more than one associated character. Move any body
    -- that was not controlled by LuaPlayer::teleport as well.
    for _, character in pairs(player.get_associated_characters()) do
        if character.valid and character.surface == target_surface then
            pcall(function()
                character.teleport({0, 2}, surfaces.ensure_hospice())
            end)
        end
    end
end

local function evacuate(surface)
    for _, player in pairs(game.players) do
        evacuate_player(player, surface)
    end
end

local function choose(list)
    return list[math.random(1, #list)]
end

local function prepare_new_round(name, surface, record)
    local planet = game.planets[name]
    if planet and planet.valid then planet.reset_map_gen_settings() end
    local settings = surface.map_gen_settings
    settings.seed = math.random(1, 2147483647)
    surface.map_gen_settings = settings

    record.round = record.round + 1
    record.seed = settings.seed
    record.solar_factor = choose(config.public_planet_solar_factors)
    record.day_factor = choose(config.public_planet_day_factors)
    record.evolution = name == 'nauvis' and math.random() or nil
end

local function begin_reset(name, surface, record)
    record.state = 'clearing'
    record.next_tick = nil
    record.warned = {}
    record.surface_index = surface.index
    record.clear_started_tick = game.tick
    game.print({'un.planet-reset-started', planet_label(name)})

    evacuate(surface)
    linked_inventory.clear_surface_dropoffs(name)
    local ok, err = pcall(function()
        prepare_new_round(name, surface, record)
        surface.clear(true)
    end)
    if not ok then
        record.state = 'open'
        record.next_tick = game.tick + config.ticks_per_minute
        record.clear_started_tick = nil
        log('[un] failed to start reset for ' .. name .. ': ' .. tostring(err))
        for _, player in pairs(game.connected_players) do
            if player.admin then
                player.print({'un.planet-reset-failed', planet_label(name)})
            end
        end
    end
end

local function clear_statistics(surface)
    for _, force in pairs(game.forces) do
        if force and force.valid then
            for _, getter in ipairs(STATISTIC_GETTERS) do
                local ok, err = pcall(function()
                    force[getter](surface).clear()
                end)
                if not ok then
                    log('[un] failed to clear ' .. getter .. ' on '
                        .. surface.name .. ': ' .. tostring(err))
                end
            end
        end
    end
end

local function finish_reset(name, surface, record)
    clear_statistics(surface)
    pcall(function()
        surface.solar_power_multiplier = (record.base_solar or 1)
            * (record.solar_factor or 1)
    end)
    pcall(function()
        surface.ticks_per_day = math.max(
            1,
            math.floor((record.base_day or surface.ticks_per_day)
                * (record.day_factor or 1))
        )
    end)
    if name == 'nauvis' and record.evolution then
        game.forces.enemy.set_evolution_factor(record.evolution, surface)
    end
    if name == 'nauvis' then surfaces.sync_all_property_environments() end
    game.forces.player.set_spawn_position({0, 0}, surface)
    surface.request_to_generate_chunks({0, 0}, 1)
    surface.force_generate_chunk_requests()

    record.state = 'open'
    record.surface_index = surface.index
    record.clear_started_tick = nil
    if settings.get('planet_resets_enabled') then
        record.next_tick = game.tick + period(name)
        record.paused_left_ticks = nil
    else
        record.next_tick = nil
        record.paused_left_ticks = period(name)
    end
    record.warned = {}
    game.print({
        'un.planet-reset-finished',
        planet_label(name),
        math.floor((record.solar_factor or 1) * 100 + 0.5),
        math.floor((record.day_factor or 1) * 100 + 0.5),
    })
end

function M.is_open(name)
    local record = storage.public_planet_resets
        and storage.public_planet_resets[name]
    return not record or record.state == 'open'
end

function M.list()
    state.ensure()
    local result = {}
    for _, name in ipairs(config.public_planets) do
        local record = storage.public_planet_resets[name]
        if not record then record = ensure_record(name) end
        result[#result + 1] = {
            name = name,
            state = record.state,
            round = record.round or 0,
            paused = record.state == 'open'
                and not settings.get('planet_resets_enabled'),
            left_ticks = record.state == 'open' and record.next_tick
                and math.max(0, record.next_tick - game.tick)
                or record.paused_left_ticks,
        }
    end
    return result
end

function M.apply_enabled(enabled)
    for _, name in ipairs(config.public_planets) do
        local record = storage.public_planet_resets[name]
        if not record then record = ensure_record(name) end
        if enabled then
            if record.state == 'open' and not record.next_tick then
                record.next_tick = game.tick
                    + (record.paused_left_ticks or period(name))
            end
            record.paused_left_ticks = nil
        elseif record.state == 'open' and record.next_tick then
            record.paused_left_ticks = math.max(0, record.next_tick - game.tick)
            record.next_tick = nil
        end
    end
end

function M.ensure()
    for _, name in ipairs(config.public_planets) do ensure_record(name) end
    if not settings.get('planet_resets_enabled') then M.apply_enabled(false) end
end

local function check_resets()
    if not settings.get('planet_resets_enabled') then return end
    for _, name in ipairs(config.public_planets) do
        local record, surface = ensure_record(name)
        if record.state == 'open' and record.next_tick then
            local left = record.next_tick - game.tick
            for _, minutes in ipairs(config.public_planet_warning_minutes) do
                local threshold = minutes * config.ticks_per_minute
                if left <= threshold and left > 0 and not record.warned[minutes] then
                    record.warned[minutes] = true
                    game.print({'un.planet-reset-warning', planet_label(name), minutes})
                end
            end
            if left <= 0 and surface and surface.valid then
                begin_reset(name, surface, record)
            end
        end
    end
end

events.on(defines.events.on_surface_cleared, function(event)
    local surface = game.surfaces[event.surface_index]
    if not (surface and surface.valid) then return end
    local record = storage.public_planet_resets
        and storage.public_planet_resets[surface.name]
    if not (record and record.state == 'clearing'
            and record.surface_index == event.surface_index) then
        return
    end
    finish_reset(surface.name, surface, record)
end)

events.on(defines.events.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local surface = player.physical_surface
    if surface and not M.is_open(surface.name) then
        evacuate_player(player, surface)
        player.print({'un.planet-reset-closed', planet_label(surface.name)})
    end
end)

scheduler.every(config.public_planet_check_ticks, check_resets)

return M
