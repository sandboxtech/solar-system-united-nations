local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local settings = require('scripts.settings')
local stamina = require('scripts.stamina')
local state = require('scripts.state')

local M = {}
local OBSERVER_PLANET = 'aquilo'

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
    local color = config.faction_chat_colors[planet_name] or '1,1,1'
    return {
        '',
        '[color=' .. color .. ']',
        '[img=space-location/' .. planet_name .. '] ',
        {'un.faction-name-' .. planet_name},
        '[/color]',
    }
end

-- Kept as a semantic alias for chat formatting. Faction identity has one
-- visual form everywhere: planet icon, faction colour, and country name.
function M.chat_display_name(planet_name)
    return M.display_name(planet_name)
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

function M.switch_stamina_cost(target_planet)
    return target_planet == 'nauvis' and 0 or config.suicide_stamina_cost
end

function M.switch_coin_cost(target_planet)
    return target_planet == 'nauvis' and 0 or config.faction_switch_coin_cost
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

local function pair_key(first, second)
    if first > second then first, second = second, first end
    return first .. ':' .. second
end

local function apply_relation(first_force, second_force, friendly)
    first_force.set_friend(second_force, friendly)
    second_force.set_friend(first_force, friendly)
    first_force.set_cease_fire(second_force, friendly)
    second_force.set_cease_fire(first_force, friendly)
end

local function ensure_diplomacy_state()
    for _, planet_name in ipairs(config.public_planets) do
        if storage.faction_diplomacy_friendly[planet_name] == nil then
            storage.faction_diplomacy_friendly[planet_name] = true
        end
    end
    storage.faction_diplomacy_friendly[OBSERVER_PLANET] = true
    for first = 1, #config.public_planets do
        for second = first + 1, #config.public_planets do
            local key = pair_key(
                config.public_planets[first],
                config.public_planets[second]
            )
            if storage.faction_pair_relations[key] == nil then
                storage.faction_pair_relations[key] = true
            end
            if config.public_planets[first] == OBSERVER_PLANET
                    or config.public_planets[second] == OBSERVER_PLANET then
                storage.faction_pair_relations[key] = true
            end
        end
    end
end

local function surface_home_planet(surface)
    if planet_set[surface.name] then return surface.name end
    local hospice_prefix = config.hospice_surface_prefix
    if surface.name:sub(1, #hospice_prefix) == hospice_prefix then
        local planet_name = surface.name:sub(#hospice_prefix + 1)
        if planet_set[planet_name] then return planet_name end
    end
    local second_hospice_prefix = config.hospice_second_surface_prefix
    if surface.name:sub(1, #second_hospice_prefix)
            == second_hospice_prefix then
        local planet_name = surface.name:sub(#second_hospice_prefix + 1)
        if planet_set[planet_name] then return planet_name end
    end
    local property_prefix = config.property_surface_prefix
    if surface.name:sub(1, #property_prefix) ~= property_prefix then return nil end
    local property_id = tonumber(surface.name:sub(#property_prefix + 1))
    local property = property_id and storage.properties
        and storage.properties[property_id] or nil
    if property and property.status == 'active'
            and property.surface_index == surface.index
            and planet_set[property.sample_planet] then
        return property.sample_planet
    end
    return nil
end

function M.apply_surface_visibility(surface)
    if not (surface and surface.valid) then return false end
    local platform = surface.platform
    if platform and platform.valid then return false end
    local home_planet = surface_home_planet(surface)
    local hide_home = settings.get('surface_hidden_from_home_faction')
    local hide_foreign = settings.get('surface_hidden_from_foreign_factions')
    for _, entry in ipairs(M.all()) do
        local hidden = home_planet and (entry.planet_name == home_planet
            and hide_home or entry.planet_name ~= home_planet and hide_foreign)
            or false
        entry.force.set_surface_hidden(surface, hidden)
    end
    return true
end

function M.apply_all_surface_visibility()
    for _, surface in pairs(game.surfaces) do
        M.apply_surface_visibility(surface)
    end
end

local function configure_relations()
    ensure_diplomacy_state()
    local entries = M.all()
    for _, entry in ipairs(entries) do
        entry.force.friendly_fire = true
        entry.force.share_chart = true
    end
    for first = 1, #entries do
        for second = first + 1, #entries do
            local a = entries[first].force
            local b = entries[second].force
            local key = pair_key(
                entries[first].planet_name,
                entries[second].planet_name
            )
            apply_relation(a, b, storage.faction_pair_relations[key])
        end
    end
    M.apply_all_surface_visibility()
end

function M.update_diplomacy_after_reset(planet_name)
    if not planet_set[planet_name] then return false end
    if planet_name == OBSERVER_PLANET then return false end
    state.ensure()
    ensure_diplomacy_state()
    local source = M.of_planet(planet_name)
    if not (source and source.valid) then return false end
    local technology = source.technologies[
        config.faction_diplomacy_technology
    ]
    if not (technology and technology.researched) then return false end

    local was_friendly = storage.faction_diplomacy_friendly[planet_name]
    local transition_chance = was_friendly
        and settings.get('faction_friendly_to_hostile_percent') / 100
        or settings.get('faction_hostile_to_friendly_percent') / 100
    if math.random() >= transition_chance then return false end

    local friendly = not was_friendly
    storage.faction_diplomacy_friendly[planet_name] = friendly
    for _, other_name in ipairs(config.public_planets) do
        if other_name ~= planet_name and other_name ~= OBSERVER_PLANET then
            local other = M.of_planet(other_name)
            if other and other.valid then
                local key = pair_key(planet_name, other_name)
                storage.faction_pair_relations[key] = friendly
                apply_relation(source, other, friendly)
            end
        end
    end
    return true, friendly
end

function M.set_all_diplomacy(friendly)
    state.ensure()
    ensure_diplomacy_state()
    for _, planet_name in ipairs(config.public_planets) do
        storage.faction_diplomacy_friendly[planet_name]
            = planet_name == OBSERVER_PLANET or friendly
    end
    for first = 1, #config.public_planets do
        for second = first + 1, #config.public_planets do
            local first_planet = config.public_planets[first]
            local second_planet = config.public_planets[second]
            local relation = first_planet == OBSERVER_PLANET
                or second_planet == OBSERVER_PLANET or friendly
            local key = pair_key(first_planet, second_planet)
            storage.faction_pair_relations[key] = relation
            local first_force = M.of_planet(first_planet)
            local second_force = M.of_planet(second_planet)
            if first_force and second_force then
                apply_relation(first_force, second_force, relation)
            end
        end
    end
    return true
end

function M.relation_caption(first_planet, second_planet)
    local first = M.of_planet(first_planet)
    local second = M.of_planet(second_planet)
    if first and second and first.get_friend(second)
            and second.get_friend(first) then
        return {'un.faction-friendly'}
    end
    return {'un.faction-hostile'}
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

local function switch_cooldown_left(player)
    local account = economy.ensure_account(player.index)
    local last_tick = tonumber(account.last_faction_switch_tick)
    if not last_tick then return 0 end
    local cooldown = config.faction_switch_cooldown_hours
        * config.ticks_per_hour
    return math.max(0, last_tick + cooldown - game.tick)
end

function M.switch_availability(player, target_planet)
    if not (player and player.valid) then return false, 'invalid-player' end
    if not planet_set[target_planet] then return false, 'invalid-planet' end
    local source_planet = M.of_player(player)
    if not source_planet then return false, 'invalid-faction' end
    if source_planet == target_planet then return false, 'same-faction' end
    if not settings.online_requirement_met(
            player,
            'faction_switch_min_online_hours'
        ) then
        return false, 'faction-online-time'
    end
    local cooldown_left = switch_cooldown_left(player)
    if cooldown_left > 0 then return false, 'faction-cooldown', cooldown_left end
    if target_planet ~= 'nauvis'
            and (not player.physical_surface
                or player.physical_surface.name ~= target_planet) then
        return false, 'faction-target-location'
    end
    if stamina.get(player.index) < M.switch_stamina_cost(target_planet) then
        return false, 'insufficient-stamina'
    end
    if economy.get_balance(player.index) < M.switch_coin_cost(target_planet) then
        return false, 'insufficient-credit'
    end
    return true
end

local function apply_switch(player, source_planet, target_planet)
    local target_force = M.of_planet(target_planet)
    if not (target_force and target_force.valid) then
        return false, 'invalid-planet'
    end
    for _, handler in ipairs(switch_cleanup_handlers) do
        local ok, err = pcall(handler, player, source_planet, target_planet)
        if not ok then
            log('[un] faction switch cleanup failed: ' .. tostring(err))
        end
    end
    player.force = target_force
    economy.ensure_account(player.index).last_faction_switch_tick = game.tick
    game.print({
        'un.faction-switch-broadcast',
        player.name,
        M.display_name(target_planet),
    })
    return true
end

function M.switch_by_suicide(player, target_planet)
    local available, err, detail = M.switch_availability(player, target_planet)
    if not available then return false, err, detail end
    local source_planet = M.of_player(player)
    local stamina_cost = M.switch_stamina_cost(target_planet)
    local coin_cost = M.switch_coin_cost(target_planet)
    local character = character_of(player)
    if not character then return false, 'no-character' end

    if coin_cost > 0 and not economy.change(
            player.index, -coin_cost, 'faction-switch'
        ) then
        return false, 'insufficient-credit'
    end
    if not stamina.spend(player.index, stamina_cost) then
        if coin_cost > 0 then
            economy.change(player.index, coin_cost, 'faction-switch-refund')
        end
        return false, 'insufficient-stamina'
    end

    if target_planet ~= 'nauvis' then
        local switched, switch_error = apply_switch(
            player, source_planet, target_planet
        )
        if not switched then
            stamina.refund(player.index, stamina_cost)
            if coin_cost > 0 then
                economy.change(player.index, coin_cost, 'faction-switch-refund')
            end
            return false, switch_error
        end
        return true
    end

    storage.pending_faction_switches[player.index] = {
        source_planet = source_planet,
        target_planet = target_planet,
        requested_tick = game.tick,
        stamina_cost = stamina_cost,
        coin_cost = coin_cost,
        respawn_seconds = config.faction_switch_nauvis_respawn_seconds,
    }
    storage.respawn_hospice_planets[player.index] = target_planet
    local died = character.die(game.forces.neutral)
    if not died then
        storage.pending_faction_switches[player.index] = nil
        storage.respawn_hospice_planets[player.index] = nil
        stamina.refund(player.index, stamina_cost)
        if coin_cost > 0 then
            economy.change(player.index, coin_cost, 'faction-switch-refund')
        end
        return false, 'death-failed'
    end
    return true
end

local function finish_switch(player)
    local pending = storage.pending_faction_switches[player.index]
    if not pending then return false end
    storage.pending_faction_switches[player.index] = nil
    if not M.of_planet(pending.target_planet) then
        log('[un] faction switch target missing: '
            .. tostring(pending.target_planet))
        return false
    end
    return apply_switch(player, pending.source_planet, pending.target_planet)
end

events.on(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if M.ensure_player(player) then
        storage.suppress_foreign_join_notifications[player.index] = true
        game.print({
            'un.faction-switch-broadcast',
            player.name,
            M.display_name(M.of_player(player)),
        })
    end
end)

events.on(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    state.ensure()
    if M.ensure_player(player) then
        game.print({
            'un.faction-switch-broadcast',
            player.name,
            M.display_name(M.of_player(player)),
        })
        return
    end
    if storage.suppress_foreign_join_notifications[player.index] then
        storage.suppress_foreign_join_notifications[player.index] = nil
        return
    end
    local planet_name = M.of_player(player)
    for _, entry in ipairs(M.all()) do
        if entry.force ~= player.force then
            entry.force.print({
                'un.player-joined-foreign',
                player.name,
                M.display_name(planet_name),
            })
        end
    end
end)

events.on(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if player then finish_switch(player) end
end)

events.on(defines.events.on_surface_created, function(event)
    M.apply_surface_visibility(game.surfaces[event.surface_index])
end)

return M
