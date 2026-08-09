local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
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

local function chest_positions(count)
    local positions = {}
    for i = 1, count do
        positions[#positions + 1] = {
            x = (i - (count + 1) / 2) * 2 + 0.5,
            y = config.property_linked_chest_y,
        }
    end
    return positions
end

local function ensure_linked_chests(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
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
    local price = math.floor(tonumber(spec.price) or 1000)
    local size = math.floor(tonumber(spec.size) or 64)
    local linked_chests = math.floor(tonumber(spec.linked_chests) or 1)
    local tax = tonumber(spec.tax) or config.property_default_tax
    if not is_positive_integer(price) or price > config.property_price_cap then
        return nil, 'invalid-price'
    end
    if not is_positive_integer(size) or size % 64 ~= 0 then
        return nil, 'invalid-size'
    end
    if not is_positive_integer(linked_chests) or linked_chests > 16 then
        return nil, 'invalid-chest-count'
    end
    if tax < 0 or tax > 1 then return nil, 'invalid-tax' end

    local id = storage.next_property_id
    storage.next_property_id = id + 1
    local surface = surfaces.create_property_surface(id, size)
    local property = {
        id = id,
        custom_name = spec.name,
        surface_name = surface.name,
        surface_index = surface.index,
        status = 'active',
        owner_index = nil,
        base_price = price,
        price_at_tick = game.tick,
        decay_ticks = config.property_decay_ticks,
        tax = tax,
        size = size,
        linked_chest_count = linked_chests,
        linked_chest_positions = chest_positions(linked_chests),
        created_tick = game.tick,
    }
    storage.properties[id] = property
    if not ensure_linked_chests(property) then
        log('[un] failed to create property linked chests for property ' .. id)
    end
    bump_revision()
    return property
end

function M.ensure_defaults()
    state.ensure()
    if storage.default_properties_created then return end
    for _, spec in ipairs(config.default_properties) do M.create(spec) end
    storage.default_properties_created = true
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
    if property.owner_index ~= player.index then return false, 'not-owner' end
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    ensure_linked_chests(property)
    return surfaces.teleport(player, surface)
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
    if not require_admin(command) then return end
    state.ensure()
    local action, first, second, third = (command.parameter or ''):match(
        '^%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)'
    )
    if action == '' or action == 'list' then
        reply(command, {'un.property-command-count', #M.list()})
    elseif action == 'create' then
        local property, err = M.create{
            price = first ~= '' and tonumber(first) or nil,
            size = second ~= '' and tonumber(second) or nil,
            linked_chests = third ~= '' and tonumber(third) or nil,
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

return M
