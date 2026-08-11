local config = require('config')
local events = require('scripts.events')
local experience = require('scripts.experience')
local factions = require('scripts.factions')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local state = require('scripts.state')
local stamina = require('scripts.stamina')
local surfaces = require('scripts.surfaces')

local M = {}
local STARTER_PACK = 'space-platform-starter-pack'

local function records()
    state.ensure()
    return storage.ships
end

local function platform_of(index, record)
    local force = record and record.force_name and game.forces[record.force_name]
    local platform = force and force.valid and force.platforms[index]
    if platform and platform.valid then return platform end
    for _, entry in ipairs(factions.all()) do
        platform = entry.force.platforms[index]
        if platform and platform.valid then return platform end
    end
    return nil
end

local function is_scheduled(platform)
    return platform and platform.valid and platform.scheduled_for_deletion > 0
end

local function is_ready(platform)
    if not (platform and platform.valid) then return false end
    local surface = platform.surface
    return surface and surface.valid or false
end

function M.is_public(player_index)
    state.ensure()
    local account = storage.players[player_index]
    return type(account) ~= 'table' or account.ship_public ~= false
end

local function apply_visibility(platform, owner_index)
    if not (platform and platform.valid) then return end
    local public = not owner_index or M.is_public(owner_index)
    platform.hidden = not public
    local surface = platform.surface
    if not (surface and surface.valid) then return end
    for _, entry in ipairs(factions.all()) do
        local visible = public or entry.force == platform.force
        entry.force.set_surface_hidden(surface, not visible)
    end
end

local function reconcile()
    local registered = records()
    for _, entry in ipairs(factions.all()) do
        for index, platform in pairs(entry.force.platforms) do
            if platform and platform.valid and not registered[index] then
                registered[index] = {
                    owner_index = nil,
                    force_name = entry.force.name,
                    planet_name = entry.planet_name,
                    created_tick = game.tick,
                    built_tick = is_ready(platform) and game.tick or nil,
                    life_ticks = config.ship_life_hours * config.ticks_per_hour,
                }
            end
        end
    end
end

local function apply_bounds(platform, owner_index)
    if not is_ready(platform) then return end
    local ok, err = pcall(function()
        local settings = platform.surface.map_gen_settings
        local level = owner_index and experience.total_level(owner_index) or 0
        settings.width = config.ship_base_width
            + config.ship_width_per_level * level
        settings.height = config.ship_height
        platform.surface.map_gen_settings = settings
    end)
    if not ok then log('[un] failed to apply ship bounds: ' .. tostring(err)) end
end

function M.life_ticks(record)
    return record.life_ticks
end

function M.left_ticks(record)
    if not record then return nil end
    if not record.built_tick then return M.life_ticks(record) end
    return record.built_tick + M.life_ticks(record) - game.tick
end

function M.of(player_index)
    reconcile()
    local best_platform = nil
    local best_record = nil
    local best_index = nil
    for index, record in pairs(records()) do
        if record.owner_index == player_index then
            local platform = platform_of(index, record)
            if not platform then
                records()[index] = nil
            elseif not (record.scuttled_tick or is_scheduled(platform))
                    and (not best_index or index < best_index) then
                best_platform = platform
                best_record = record
                best_index = index
            end
        end
    end
    return best_platform, best_record
end

function M.list(viewer_index)
    reconcile()
    local result = {}
    for index, record in pairs(records()) do
        local platform = platform_of(index, record)
        if not platform then
            records()[index] = nil
        elseif record.owner_index
                and not (record.scuttled_tick or is_scheduled(platform)) then
            if not viewer_index or record.owner_index == viewer_index
                    or M.is_public(record.owner_index) then
                result[#result + 1] = {
                    index = index,
                    platform = platform,
                    record = record,
                    owner_index = record.owner_index,
                }
            end
        end
    end
    table.sort(result, function(a, b)
        if a.owner_index ~= b.owner_index then
            return a.owner_index < b.owner_index
        end
        return a.index < b.index
    end)
    return result
end


function M.set_public(player_index, public)
    state.ensure()
    local account = storage.players[player_index]
    if type(account) ~= 'table' then
        account = {}
        storage.players[player_index] = account
    end
    account.ship_public = public == true
    local platform = M.of(player_index)
    if platform then apply_visibility(platform, player_index) end
    return true
end

function M.enforce_lock()
    for _, entry in ipairs(factions.all()) do
        local force = entry.force
        if config.ship_lock_native_creation then
            if force.is_space_platforms_unlocked() then
                force.lock_space_platforms()
            end
        elseif not force.is_space_platforms_unlocked() then
            force.unlock_space_platforms()
        end
    end
end

function M.create(player, planet_name)
    if not (player and player.valid) then return nil, 'ship-create-failed' end
    local faction_planet = factions.of_player(player)
    if not faction_planet or planet_name ~= faction_planet then
        return nil, 'ship-invalid-planet'
    end
    if M.of(player.index) then return nil, 'ship-already-have' end
    if not settings.online_requirement_met(
            player,
            'ship_build_min_online_hours'
        ) then
        return nil, 'ship-online-time'
    end

    if not stamina.spend(player.index, config.ship_stamina_cost) then
        return nil, 'insufficient-stamina'
    end

    local created, platform = pcall(function()
        return player.force.create_space_platform{
            name = player.name,
            planet = planet_name,
            starter_pack = STARTER_PACK,
        }
    end)
    if not created or not platform then
        stamina.refund(player.index, config.ship_stamina_cost)
        if not created then
            log('[un] failed to create ship: ' .. tostring(platform))
        end
        return nil, 'ship-create-failed'
    end

    local record = {
        owner_index = player.index,
        force_name = player.force.name,
        planet_name = planet_name,
        created_tick = game.tick,
        life_ticks = (settings.get('ship_life_hours')
            + experience.total_level(player.index)) * config.ticks_per_hour,
    }
    records()[platform.index] = record
    local applied, apply_err = pcall(function() platform.apply_starter_pack() end)
    if not applied then
        record.scuttled_tick = game.tick
        platform.destroy(1)
        stamina.refund(player.index, config.ship_stamina_cost)
        log('[un] failed to apply ship starter pack: ' .. tostring(apply_err))
        return nil, 'ship-create-failed'
    end

    if is_ready(platform) then record.built_tick = game.tick end
    apply_bounds(platform, player.index)
    apply_visibility(platform, player.index)
    game.print({
        'un.ship-built-broadcast',
        player.name,
        {
            '',
            '[planet=' .. planet_name .. '] ',
            {'space-location-name.' .. planet_name},
        },
        factions.display_name(factions.of_player(player)),
    })
    return platform
end

function M.enter(player)
    local platform = M.of(player.index)
    if not platform then return false, 'ship-missing' end
    if not is_ready(platform) then return false, 'ship-not-ready' end
    return surfaces.teleport(player, platform.surface)
end

function M.scuttle(player)
    local platform, record = M.of(player.index)
    if not platform then return false, 'ship-missing' end
    record.scuttled_tick = game.tick
    platform.destroy(1)
    return true
end

function M.remove_owner(player_index)
    local removed = 0
    for index, record in pairs(records()) do
        if record.owner_index == player_index then
            local platform = platform_of(index, record)
            if platform and not is_scheduled(platform) then
                record.scuttled_tick = game.tick
                platform.destroy(1)
            end
            records()[index] = nil
            removed = removed + 1
        end
    end
    return removed
end

function M.ensure()
    reconcile()
    M.enforce_lock()
    for index, record in pairs(records()) do
        local platform = platform_of(index, record)
        if platform then
            apply_bounds(platform, record.owner_index)
            apply_visibility(platform, record.owner_index)
        end
    end
end

local function on_platform_surface(surface)
    if not (surface and surface.valid) then return end
    local platform = surface.platform
    if not (platform and platform.valid) then return end
    local record = records()[platform.index]
    if not record then
        record = {
            owner_index = nil,
            force_name = platform.force.name,
            planet_name = factions.planet_of_force(platform.force),
            created_tick = game.tick,
        }
        records()[platform.index] = record
    end
    record.built_tick = record.built_tick or game.tick
    apply_bounds(platform, record.owner_index)
    apply_visibility(platform, record.owner_index)
end

events.on(defines.events.on_surface_created, function(event)
    on_platform_surface(game.surfaces[event.surface_index])
end)

events.on(defines.events.on_research_finished, function()
    M.enforce_lock()
end)

scheduler.every(config.ship_lifecycle_ticks, function()
    reconcile()
    M.enforce_lock()
    for index, record in pairs(records()) do
        local platform = platform_of(index, record)
        if not platform then
            records()[index] = nil
        elseif record.built_tick and M.left_ticks(record) <= 0
                and not (record.scuttled_tick or is_scheduled(platform)) then
            record.scuttled_tick = game.tick
            platform.destroy(1)
            local owner = record.owner_index and game.get_player(record.owner_index)
            game.print({'un.ship-expired', owner and owner.name or platform.name})
        end
    end
end)

factions.on_switch_cleanup(function(player, source_planet)
    local source_force = factions.of_planet(source_planet)
    local platform, record = M.of(player.index)
    if platform and source_force and platform.force == source_force then
        record.scuttled_tick = game.tick
        platform.destroy(1)
    end
end)

return M
