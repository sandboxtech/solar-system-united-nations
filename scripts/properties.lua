local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local scheduler = require('scripts.scheduler')
local social = require('scripts.social')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

local function bump_revision()
    storage.property_revision = (storage.property_revision or 0) + 1
end

local function is_positive_integer(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

function M.display_name(property)
    return property.custom_name or {'un.property-default-name', property.id}
end

local function property_name_position(property)
    local height = property.height or property.size or 0
    return {x = 0, y = -height / 2 - 4}
end

local function ensure_property_name_rendering(property, text)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
    local object = property.name_render_id
        and rendering.get_object_by_id(property.name_render_id)
    if object and object.valid then
        object.text = text
        object.target = property_name_position(property)
        return true
    end
    object = rendering.draw_text{
        text = text,
        surface = surface,
        target = property_name_position(property),
        color = {r = 0.35, g = 0.8, b = 1},
        font = 'default-large-bold',
        alignment = 'center',
        vertical_alignment = 'bottom',
        scale = 2,
        scale_with_zoom = true,
    }
    property.name_render_id = object.id
    return true
end

local function property_rendering_fallback(property)
    if type(property.custom_name) == 'string' then return property.custom_name end
    return '#' .. tostring(property.id)
end

local function first_connected_player()
    local selected = nil
    for _, player in pairs(game.connected_players) do
        if not selected or player.index < selected.index then selected = player end
    end
    return selected
end

local function request_property_name_translation(property, player)
    if type(property.custom_name) == 'string' then
        return ensure_property_name_rendering(property, property.custom_name)
    end
    if not (player and player.valid and player.connected) then return false end
    local request_id = player.request_translation(M.display_name(property))
    if not request_id then return false end
    storage.property_name_translation_requests[request_id] = {
        property_id = property.id,
        player_index = player.index,
        owner_token = property.owner_index or 0,
    }
    return true
end

function M.feature_description(property)
    local width = property.width or property.size or 0
    local height = property.height or property.size or 0
    local shape = property.shape == 'square'
        and {'un.property-shape-square'}
        or property.shape == 'long' and {'un.property-shape-long'}
        or {'un.property-shape-rectangle'}
    local sample_planet = property.sample_planet
    local sample_description = sample_planet and {
        '',
        '[planet=' .. sample_planet .. '] ',
        {'space-location-name.' .. sample_planet},
    } or {'un.property-sample-legacy'}
    return {
        'un.property-features',
        width,
        height,
        shape,
        sample_description,
        math.floor((property.solar or 1) * 100 + 0.5),
    }
end

local function central_chest_positions()
    return {
        {x = -0.5, y = -0.5},
        {x = 0.5, y = -0.5},
        {x = -0.5, y = 0.5},
        {x = 0.5, y = 0.5},
    }
end

local function position_key(position)
    return tostring(position.x) .. ',' .. tostring(position.y)
end

local function normalize_linked_chest_positions(property, surface)
    local target = central_chest_positions()
    local target_keys = {}
    for _, position in ipairs(target) do
        target_keys[position_key(position)] = true
    end

    for _, position in ipairs(property.linked_chest_positions or {}) do
        if not target_keys[position_key(position)] then
            local chest = surface.find_entity(config.linked_chest_name, position)
            if chest and chest.valid then chest.destroy() end
        end
    end

    property.linked_chest_positions = target
    property.linked_chest_count = nil
end

local function ensure_linked_chests(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
    surface.localised_name = M.display_name(property)
    surface.always_day = true
    surface.solar_power_multiplier = property.solar or 1
    normalize_linked_chest_positions(property, surface)
    local link_id = property.owner_index or config.property_link_id_unowned
    for _, position in ipairs(property.linked_chest_positions) do
        local chest = surface.find_entity(config.linked_chest_name, position)
        if not (chest and chest.valid) then
            chest = surface.create_entity{
                name = config.linked_chest_name,
                position = position,
                force = game.forces.player,
                raise_built = false,
            }
        end
        if not (chest and chest.valid) then return false end
        chest.link_id = link_id
        chest.operable = false
        chest.destructible = false
        chest.minable = false
    end
    return true
end

function M.create(spec)
    state.ensure()
    spec = spec or {}
    local price
    if spec.price == nil then
        price = math.random(
            config.property_initial_price_min,
            config.property_initial_price_max
        )
    else
        price = math.floor(tonumber(spec.price) or 0)
    end
    local tax = tonumber(spec.tax) or config.property_default_tax
    local solar = tonumber(spec.solar) or 1
    local sides = config.property_side_lengths
    local width = tonumber(spec.width)
        or sides[math.random(1, #sides)]
    local height = tonumber(spec.height)
        or sides[math.random(1, #sides)]
    local shape = width == height and 'square' or 'rectangle'
    if not is_positive_integer(price) or price > config.property_price_cap then
        return nil, 'invalid-price'
    end
    if not is_positive_integer(width) or not is_positive_integer(height) then
        return nil, 'invalid-size'
    end
    local valid_width, valid_height = false, false
    for _, side in ipairs(sides) do
        if width == side then valid_width = true end
        if height == side then valid_height = true end
    end
    if not valid_width or not valid_height
            or width > config.property_max_size
            or height > config.property_max_size then
        return nil, 'invalid-size'
    end
    if solar < 0 then return nil, 'invalid-solar' end
    if tax < 0 or tax > 1 then return nil, 'invalid-tax' end

    local id = storage.next_property_id
    local surface, half_width, half_height, sample_planet, sample_position
        = surfaces.create_property_surface(id, {
        width = width,
        height = height,
        solar = solar,
        sample_planet = spec.sample_planet,
    })
    if not surface then return nil, 'surface-create-failed' end
    storage.next_property_id = id + 1
    local property = {
        id = id,
        custom_name = nil,
        surface_name = surface.name,
        surface_index = surface.index,
        status = 'active',
        owner_index = nil,
        base_price = price,
        price_at_tick = game.tick,
        decay_ticks = config.property_decay_ticks,
        tax = tax,
        width = width,
        height = height,
        shape = shape,
        solar = solar,
        sample_planet = sample_planet,
        sample_position = sample_position,
        linked_chest_positions = central_chest_positions(),
        created_tick = game.tick,
    }
    storage.properties[id] = property
    ensure_property_name_rendering(property, property_rendering_fallback(property))
    local translator = first_connected_player()
    if translator then request_property_name_translation(property, translator) end
    if not ensure_linked_chests(property) then
        log('[un] failed to create property linked chests for property ' .. id)
    end
    bump_revision()
    return property
end

function M.ensure_defaults()
    state.ensure()
    if not storage.default_properties_created then
        for _, spec in ipairs(config.default_properties) do M.create(spec) end
        storage.default_properties_created = true
    end
    if storage.property_tax_version ~= 1 then
        for _, property in ipairs(M.list()) do
            property.tax = config.property_default_tax
        end
        storage.property_tax_version = 1
        bump_revision()
    end
    -- Configuration loading is also the one-shot repair path for properties
    -- created before all homes used the fixed central four-chest layout.
    for _, property in ipairs(M.list()) do
        ensure_linked_chests(property)
        ensure_property_name_rendering(
            property,
            property.rendered_name or property_rendering_fallback(property)
        )
        if property.owner_index then
            request_property_name_translation(
                property,
                game.get_player(property.owner_index)
            )
        elseif not property.rendered_name then
            local translator = first_connected_player()
            if translator then request_property_name_translation(property, translator) end
        end
    end
end

function M.get(property_id)
    state.ensure()
    local property = storage.properties[tonumber(property_id)]
    if property and property.status == 'active' then return property end
    return nil
end

function M.list()
    state.ensure()
    local result = {}
    for _, property in pairs(storage.properties) do
        if property.status == 'active' then result[#result + 1] = property end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

function M.current_price(property, tick)
    tick = tick or game.tick
    local exponent = (property.price_at_tick - tick) / property.decay_ticks
    local raw = property.base_price * (10 ^ exponent)
    if raw >= config.property_price_cap then return config.property_price_cap end
    if raw <= 1 then return 1 end
    return math.ceil(raw)
end

function M.owner_name(property)
    if not property.owner_index then return nil end
    local player = game.get_player(property.owner_index)
    if player then return player.name end
    local account = storage.players[property.owner_index]
    return account and account.name or ('#' .. property.owner_index)
end

function M.buy(player, property_id, quoted_price)
    local property = M.get(property_id)
    if not property then return false, 'missing' end
    if property.owner_index == player.index then return false, 'already-owner' end

    local price = M.current_price(property)
    if quoted_price and price > quoted_price then return false, 'price-increased', price end
    local payout = math.floor(price * (1 - property.tax))
    local ok, err = economy.taxed_transfer(
        player.index,
        property.owner_index,
        price,
        payout,
        'property-purchase'
    )
    if not ok then return false, err end

    property.owner_index = player.index
    property.base_price = price
    property.price_at_tick = game.tick + property.decay_ticks
    property.purchased_tick = game.tick
    property.purchase_price = price
    request_property_name_translation(property, player)
    if not ensure_linked_chests(property) then
        log('[un] property relink failed for property ' .. property.id)
    end
    bump_revision()
    return true, price
end

function M.renew_fee(property)
    return math.max(1, math.ceil(property.base_price * property.tax))
end

function M.renew(player, property_id)
    local property = M.get(property_id)
    if not property then return false, 'missing' end
    if property.owner_index ~= player.index then return false, 'not-owner' end
    local next_tick = property.price_at_tick + property.decay_ticks
    if next_tick > game.tick + config.property_max_future_ticks then
        return false, 'renew-limit'
    end
    local fee = M.renew_fee(property)
    local ok, err = economy.change(player.index, -fee, 'property-renew')
    if not ok then return false, err end
    property.price_at_tick = next_tick
    property.last_renew_tick = game.tick
    bump_revision()
    return true, fee
end

function M.enter(player, property_id)
    local property = M.get(property_id)
    if not property then return false, 'missing' end
    if property.owner_index ~= player.index
            and not player.admin
            and not social.are_mutual(player.index, property.owner_index) then
        return false, 'not-owner'
    end
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    ensure_linked_chests(property)
    local ok, err
    if player.admin then
        ok, err = surfaces.teleport_near(player, surface, {0, 0}, false)
    else
        ok, err = surfaces.teleport(player, surface)
    end
    if ok and property.owner_index == player.index then
        economy.ensure_account(player.index).last_property_id = property.id
    end
    return ok, err
end

function M.enter_last_owned(player)
    local account = economy.ensure_account(player.index)
    local property = M.get(account.last_property_id)
    if not property or property.owner_index ~= player.index then
        account.last_property_id = nil
        return surfaces.to_hospice(player)
    end
    return M.enter(player, property.id)
end

local function command_player(command)
    return command.player_index and game.get_player(command.player_index) or nil
end

local function reply(command, message)
    local player = command_player(command)
    if player then player.print(message) else localised_print(message) end
end

local function require_admin(command)
    local player = command_player(command)
    if player and not player.admin then
        player.print({'un.admin-only'})
        return false
    end
    return true
end

local function property_at_player_body(player)
    local surface = player.physical_surface
    if not (surface and surface.valid) then return nil end
    for _, property in ipairs(M.list()) do
        if property.surface_index == surface.index then return property end
    end
    return nil
end

local function valid_custom_name(name)
    if name == '' or #name > 256 or name:find('%c') then return false end
    local characters = 0
    for index = 1, #name do
        local byte = name:byte(index)
        if byte < 128 or byte >= 192 then characters = characters + 1 end
    end
    return characters <= 64
end

local function rename_from_command(command, parameter)
    local player = command_player(command)
    if not player then
        reply(command, {'un.property-rename-player-only'})
        return
    end
    local property = property_at_player_body(player)
    if not property then
        player.print({'un.property-rename-not-inside'})
        return
    end
    if property.owner_index ~= player.index then
        player.print({'un.property-rename-not-owner'})
        return
    end
    local name = parameter:match('^%s*rename%s+(.+)%s*$') or ''
    name = name:match('^%s*(.-)%s*$') or ''
    if not valid_custom_name(name) then
        player.print({'un.property-rename-invalid'})
        return
    end
    property.custom_name = name
    property.rendered_name = name
    property.rendered_name_locale = nil
    local surface = game.surfaces[property.surface_name]
    if surface and surface.valid then surface.localised_name = name end
    ensure_property_name_rendering(property, name)
    bump_revision()
    player.print({'un.property-renamed', property.id, name})
end

local function deletion_blocker(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return nil end
    for _, player in pairs(game.players) do
        if player.physical_surface == surface or player.surface == surface then
            return player.name
        end
    end
    return nil
end

local function active_player_count()
    local count = 0
    for player_index, account in pairs(storage.players) do
        local player = game.get_player(player_index)
        local last_seen = player and player.connected and game.tick
            or account.last_seen_tick or account.created_tick or 0
        if game.tick - last_seen <= config.property_supply_active_window_ticks then
            count = count + 1
        end
    end
    return count
end

local function median_price(list)
    local prices = {}
    for _, property in ipairs(list) do
        prices[#prices + 1] = M.current_price(property)
    end
    table.sort(prices)
    local count = #prices
    if count == 0 then return 0 end
    if count % 2 == 1 then return prices[(count + 1) / 2] end
    return (prices[count / 2] + prices[count / 2 + 1]) / 2
end

local function choose_retirement_candidate(list)
    local candidates = {}
    for _, property in ipairs(list) do
        local surface = game.surfaces[property.surface_name]
        local last_trade = property.purchased_tick or property.created_tick or game.tick
        if not property.owner_index
                and surface and surface.valid
                and not deletion_blocker(property)
                and game.tick - last_trade >= config.property_supply_stale_ticks then
            candidates[#candidates + 1] = property
        end
    end
    table.sort(candidates, function(a, b)
        local a_tick = a.purchased_tick or a.created_tick or 0
        local b_tick = b.purchased_tick or b.created_tick or 0
        if a_tick ~= b_tick then return a_tick < b_tick end
        return a.id < b.id
    end)
    return candidates[1]
end

local function retire_property(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then
        storage.properties[property.id] = nil
        bump_revision()
        return true
    end
    storage.deleting_properties[surface.index] = property.id
    if game.delete_surface(surface) then return true end
    storage.deleting_properties[surface.index] = nil
    return false
end

local function evaluate_supply()
    state.ensure()
    local list = M.list()
    local total = #list
    local unowned = 0
    for _, property in ipairs(list) do
        if not property.owner_index then unowned = unowned + 1 end
    end
    local active = active_player_count()
    local target = math.max(
        config.property_supply_minimum,
        active * config.property_supply_per_active_player
    )
    local vacancy = total > 0 and unowned / total or 0
    local median = median_price(list)
    local expand = total < target
        or (active > 0 and vacancy < config.property_supply_low_vacancy)
        or (active > 0 and median > config.property_supply_high_median_price)
    local candidate = choose_retirement_candidate(list)
    local contract = total > target
        and vacancy > config.property_supply_high_vacancy
        and median < config.property_supply_low_median_price
        and candidate ~= nil
    local supply = storage.property_supply

    if expand and not contract then
        supply.expand_checks = (supply.expand_checks or 0) + 1
        supply.contract_checks = 0
        if supply.expand_checks >= config.property_supply_confirmation_checks
                and math.random() < config.property_supply_change_chance then
            local solar_levels = {0.1, 1, 10}
            local property = M.create{
                solar = solar_levels[math.random(1, #solar_levels)],
            }
            if property then supply.expand_checks = 0 end
        end
    elseif contract then
        supply.contract_checks = (supply.contract_checks or 0) + 1
        supply.expand_checks = 0
        if supply.contract_checks >= config.property_supply_confirmation_checks
                and math.random() < config.property_supply_change_chance
                and retire_property(candidate) then
            supply.contract_checks = 0
        end
    else
        supply.expand_checks = 0
        supply.contract_checks = 0
    end
end

local function delete_confirmed(command, property)
    local blocker = deletion_blocker(property)
    if blocker then
        reply(command, {'un.property-delete-occupied', blocker})
        return
    end
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then
        storage.properties[property.id] = nil
        bump_revision()
        reply(command, {'un.property-delete-done', property.id})
        return
    end
    property.status = 'deleting'
    storage.deleting_properties[surface.index] = property.id
    if game.delete_surface(surface) then
        reply(command, {'un.property-delete-queued', property.id})
    else
        storage.deleting_properties[surface.index] = nil
        property.status = 'active'
        reply(command, {'un.property-delete-failed', property.id})
    end
end

local function on_command(command)
    state.ensure()
    local parameter = command.parameter or ''
    local action, first, second, third = parameter:match(
        '^%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)'
    )
    if action == 'rename' then
        rename_from_command(command, parameter)
        return
    end
    if not require_admin(command) then return end
    if action == '' or action == 'list' then
        reply(command, {'un.property-command-count', #M.list()})
    elseif action == 'create' then
        local property, err = M.create{
            price = first ~= '' and tonumber(first) or nil,
            width = second ~= '' and tonumber(second) or nil,
            height = third ~= '' and tonumber(third) or nil,
        }
        if property then
            reply(command, {'un.property-created', property.id})
        else
            reply(command, {'un.property-command-error'})
        end
    elseif action == 'delete' then
        local property = M.get(tonumber(first))
        if not property then
            reply(command, {'un.property-missing'})
            return
        end
        local key = command.player_index or 0
        storage.property_delete_confirm[key] = {
            property_id = property.id,
            expires_tick = game.tick + config.ticks_per_minute,
        }
        reply(command, {'un.property-delete-preview', property.id})
    elseif action == 'delete-confirm' then
        local key = command.player_index or 0
        local confirmation = storage.property_delete_confirm[key]
        local id = tonumber(first)
        storage.property_delete_confirm[key] = nil
        if not (confirmation and confirmation.property_id == id
                and confirmation.expires_tick >= game.tick) then
            reply(command, {'un.property-delete-confirm-required'})
            return
        end
        local property = M.get(id)
        if property then delete_confirmed(command, property) end
    elseif action == 'repair' then
        M.ensure_defaults()
        for _, property in ipairs(M.list()) do ensure_linked_chests(property) end
        reply(command, {'un.property-repaired', #M.list()})
    else
        reply(command, {'un.property-command-usage'})
    end
end

commands.add_command('un-property', {'un.property-command-help'}, on_command)

events.on(defines.events.on_surface_deleted, function(event)
    state.ensure()
    local property_id = storage.deleting_properties[event.surface_index]
    if not property_id then return end
    storage.deleting_properties[event.surface_index] = nil
    storage.properties[property_id] = nil
    bump_revision()
end)

events.on(defines.events.on_string_translated, function(event)
    state.ensure()
    local request = storage.property_name_translation_requests[event.id]
    if not request then return end
    storage.property_name_translation_requests[event.id] = nil
    local property = M.get(request.property_id)
    if not property then return end
    local owner_token = request.owner_token
    if owner_token == nil then owner_token = request.owner_index or 0 end
    if (property.owner_index or 0) ~= owner_token then return end
    if type(property.custom_name) == 'string' then return end
    local player_index = request.player_index or request.owner_index
    if event.player_index ~= player_index or not event.translated then return end
    property.rendered_name = event.result
    local player = game.get_player(event.player_index)
    property.rendered_name_locale = player and player.locale or nil
    ensure_property_name_rendering(property, event.result)
end)

local function refresh_owned_name_renderings(event)
    local player = game.get_player(event.player_index)
    if not (player and player.connected) then return end
    for _, property in ipairs(M.list()) do
        if property.owner_index == player.index then
            request_property_name_translation(property, player)
        elseif not property.owner_index and not property.rendered_name then
            request_property_name_translation(property, player)
        end
    end
end

events.on(defines.events.on_player_joined_game, refresh_owned_name_renderings)
events.on(defines.events.on_player_locale_changed, refresh_owned_name_renderings)

scheduler.every(config.property_supply_check_ticks, evaluate_supply)

return M
