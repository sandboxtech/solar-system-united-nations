local config = require('config')
local events = require('scripts.events')
local settings = require('scripts.settings')
local state = require('scripts.state')

local M = {}

local MAX_SAFE_INTEGER = 9007199254740991
local balance_handlers = {}

local function is_finite_integer(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and math.abs(value) <= MAX_SAFE_INTEGER
        and value == math.floor(value)
end

local function notify_balance_changed(player_index, balance)
    storage.player_data_revision = (storage.player_data_revision or 0) + 1
    for _, handler in ipairs(balance_handlers) do
        local ok, err = pcall(handler, player_index, balance)
        if not ok then log('[un] balance handler failed: ' .. tostring(err)) end
    end
end

function M.ensure_account(player_index)
    state.ensure()
    local player = game.get_player(player_index)
    local account = storage.players[player_index]
    if type(account) ~= 'table' then
        account = {
            credit = settings.get('initial_coin'),
            created_tick = game.tick,
            last_seen_tick = game.tick,
        }
        storage.players[player_index] = account
    end
    if account.credit == nil then account.credit = settings.get('initial_coin') end
    if account.created_tick == nil then
        account.created_tick = math.max(0, game.tick - (player and player.online_time or 0))
    end
    if account.ubi_anchor_tick == nil then account.ubi_anchor_tick = game.tick end
    if player then account.name = player.name end
    return account
end

function M.get_balance(player_index)
    return M.ensure_account(player_index).credit
end

function M.get_ubi_capacity()
    return config.ubi_credit_per_second * config.ubi_max_seconds
end

function M.get_claimable_ubi(player_index)
    local account = M.ensure_account(player_index)
    local elapsed_ticks = game.tick - account.ubi_anchor_tick
    if elapsed_ticks <= 0 then return 0 end
    local elapsed_seconds = math.floor(elapsed_ticks / config.ticks_per_second)
    local credited_seconds = math.min(elapsed_seconds, config.ubi_max_seconds)
    return credited_seconds * config.ubi_credit_per_second
end

function M.change(player_index, amount, reason)
    if not is_finite_integer(amount) or amount == 0 then
        return false, 'invalid-amount'
    end
    if type(reason) ~= 'string' or reason == '' then
        return false, 'invalid-reason'
    end

    local account = M.ensure_account(player_index)
    if not is_finite_integer(account.credit) or account.credit < 0 then
        return false, 'invalid-balance'
    end
    if amount < 0 and account.credit < -amount then
        return false, 'insufficient-credit'
    end

    local next_balance = account.credit + amount
    if not is_finite_integer(next_balance) or next_balance < 0 then
        return false, 'invalid-result'
    end

    account.credit = next_balance
    notify_balance_changed(player_index, next_balance)
    return true, next_balance
end

function M.transfer(from_index, to_index, amount, fee, reason)
    if from_index == to_index then return false, 'same-account' end
    if not is_finite_integer(amount) or amount <= 0 then
        return false, 'invalid-amount'
    end
    if not is_finite_integer(fee) or fee < 0 or fee > amount then
        return false, 'invalid-fee'
    end

    local from = M.ensure_account(from_index)
    local to = M.ensure_account(to_index)
    local payout = amount - fee
    if not is_finite_integer(from.credit) or from.credit < amount then
        return false, 'insufficient-credit'
    end
    if not is_finite_integer(to.credit) or to.credit < 0 then
        return false, 'invalid-balance'
    end

    local next_to = to.credit + payout
    if not is_finite_integer(next_to) then return false, 'invalid-result' end

    -- Validate both results before mutating either account, then commit the pair.
    from.credit = from.credit - amount
    to.credit = next_to
    notify_balance_changed(from_index, from.credit)
    notify_balance_changed(to_index, to.credit)
    return true, payout
end

function M.taxed_transfer(from_index, to_index, price, payout, reason)
    if not is_finite_integer(price) or price <= 0 then
        return false, 'invalid-amount'
    end
    if not is_finite_integer(payout) or payout < 0 or payout > price then
        return false, 'invalid-payout'
    end

    local buyer = M.ensure_account(from_index)
    if not is_finite_integer(buyer.credit) then
        return false, 'invalid-balance'
    end

    if from_index == to_index then
        local tax = price - payout
        if buyer.credit < tax then return false, 'insufficient-credit' end
        if tax > 0 then
            buyer.credit = buyer.credit - tax
            notify_balance_changed(from_index, buyer.credit)
        end
        return true
    end

    if buyer.credit < price then
        return false, 'insufficient-credit'
    end

    local seller = nil
    local next_seller = nil
    if to_index then
        seller = M.ensure_account(to_index)
        if not is_finite_integer(seller.credit) or seller.credit < 0 then
            return false, 'invalid-balance'
        end
        next_seller = seller.credit + payout
        if not is_finite_integer(next_seller) then return false, 'invalid-result' end
    end

    buyer.credit = buyer.credit - price
    if seller then seller.credit = next_seller end
    notify_balance_changed(from_index, buyer.credit)
    if seller then notify_balance_changed(to_index, seller.credit) end
    return true
end

function M.on_balance_changed(handler)
    balance_handlers[#balance_handlers + 1] = handler
end

function M.claim_ubi(player_index)
    local account = M.ensure_account(player_index)
    local elapsed_ticks = game.tick - account.ubi_anchor_tick
    if elapsed_ticks <= 0 then return false, 'nothing-to-claim' end

    local elapsed_seconds = math.floor(elapsed_ticks / config.ticks_per_second)
    local credited_seconds = math.min(elapsed_seconds, config.ubi_max_seconds)
    local amount = credited_seconds * config.ubi_credit_per_second
    if amount <= 0 then return false, 'nothing-to-claim' end

    local ok, result = M.change(player_index, amount, 'ubi-claim')
    if not ok then return false, result end

    if elapsed_seconds >= config.ubi_max_seconds then
        account.ubi_anchor_tick = game.tick
    else
        account.ubi_anchor_tick = account.ubi_anchor_tick
            + credited_seconds * config.ticks_per_second
    end
    return true, amount
end

local function ensure_player(event)
    local account = M.ensure_account(event.player_index)
    account.last_seen_tick = game.tick
end

events.on(defines.events.on_player_created, ensure_player)
events.on(defines.events.on_player_joined_game, ensure_player)
events.on(defines.events.on_player_left_game, function(event)
    local account = M.ensure_account(event.player_index)
    account.last_seen_tick = game.tick
end)

return M
