local config = require('config')
local events = require('scripts.events')
local stamina = require('scripts.stamina')
local state = require('scripts.state')

local M = {}

local planet_set = {}
for _, planet_name in ipairs(config.public_planets) do
    planet_set[planet_name] = true
end

local switch_cleanup_handlers = {}

function M.force_name(planet_name)
    if not planet_set[planet_name] then return nil end
    return config.faction_force_prefix .. planet_name
end

function M.display_name(planet_name)
    if not planet_set[planet_name] then return {'un.faction-unknown'} end
    return {
        '',
        '[planet=' .. planet_name .. '] ',
        {'un.faction-name-' .. planet_name},
    }
end

function M.planet_of_force(force)
    if not (force and force.valid) then return nil end
    local prefix = config.faction_force_prefix
    if force.name:sub(1, #prefix) ~= prefix then return nil end
    local planet_name = force.name:sub(#prefix + 1)
    return planet_set[planet_name] and planet_name or nil
end

function M.of_planet(planet_name)
    local name = M.force_name(planet_name)
    return name and game.forces[name] or nil
end

function M.of_player(player)
    return player and M.planet_of_force(player.force) or nil
end

function M.all()
    local result = {}
    for _, planet_name in ipairs(config.public_planets) do
        local force = M.of_planet(planet_name)
        if force and force.valid then
            result[#result + 1] = {planet_name = planet_name, force = force}
        end
    end
    return result
end

local function configure_relations()
    local entries = M.all()
    for _, entry in ipairs(entries) do
        entry.force.friendly_fire = true
    end
    for first = 1, #entries do
        for second = first + 1, #entries do
            local a = entries[first].force
            local b = entries[second].force
            a.set_friend(b, false)
            b.set_friend(a, false)
            a.set_cease_fire(b, false)
            b.set_cease_fire(a, false)
        end
    end
end

function M.ensure()
    state.ensure()
    for _, planet_name in ipairs(config.public_planets) do
        local name = M.force_name(planet_name)
        if not game.forces[name] then game.create_force(name) end
    end
    configure_relations()
end

function M.ensure_player(player)
    if not (player and player.valid) then return false end
    local planet_name = M.of_player(player)
    if planet_name then return false end
    M.ensure()
    player.force = M.of_planet('nauvis')
    return true
end

function M.on_switch_cleanup(handler)
    switch_cleanup_handlers[#switch_cleanup_handlers + 1] = handler
end

local function character_of(player)
    local character = player.character
    if character and character.valid then return character end
    for _, candidate in pairs(player.get_associated_characters()) do
        if candidate.valid then return candidate end
    end
    return nil
end

function M.switch_by_suicide(player, target_planet)
    if not (player and player.valid) then return false, 'invalid-player' end
    if not planet_set[target_planet] then return false, 'invalid-planet' end
    local source_planet = M.of_player(player)
    if not source_planet then return false, 'invalid-faction' end
    if source_planet == target_planet then return false, 'same-faction' end
    if stamina.get(player.index) < config.suicide_stamina_cost then
        return false, 'insufficient-stamina'
    end
    local character = character_of(player)
    if not character then return false, 'no-character' end

    storage.pending_faction_switches[player.index] = {
        source_planet = source_planet,
        target_planet = target_planet,
        requested_tick = game.tick,
    }
    storage.respawn_hospice_planets[player.index] = target_planet
    local died = character.die(game.forces.neutral)
    if not died then
        storage.pending_faction_switches[player.index] = nil
        storage.respawn_hospice_planets[player.index] = nil
        return false, 'death-failed'
    end
    if not stamina.spend(player.index, config.suicide_stamina_cost) then
        log('[un] faction switch stamina charge failed for player '
            .. tostring(player.index))
    end
    return true
end

local function finish_switch(player)
    local pending = storage.pending_faction_switches[player.index]
    if not pending then return false end
    storage.pending_faction_switches[player.index] = nil
    local target_force = M.of_planet(pending.target_planet)
    if not (target_force and target_force.valid) then
        log('[un] faction switch target missing: '
            .. tostring(pending.target_planet))
        return false
    end
    for _, handler in ipairs(switch_cleanup_handlers) do
        local ok, err = pcall(
            handler,
            player,
            pending.source_planet,
            pending.target_planet
        )
        if not ok then
            log('[un] faction switch cleanup failed: ' .. tostring(err))
        end
    end
    player.force = target_force
    return true
end

events.on(defines.events.on_player_created, function(event)
    M.ensure_player(game.get_player(event.player_index))
end)

events.on(defines.events.on_player_joined_game, function(event)
    M.ensure_player(game.get_player(event.player_index))
end)

events.on(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if player then finish_switch(player) end
end)

return M
