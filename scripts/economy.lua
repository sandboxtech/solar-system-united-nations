local config = require('config')
local events = require('scripts.events')
local state = require('scripts.state')

local M = {}

local balance_handlers = {}

local function is_finite_integer(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value == math.floor(value)
end

local function append_ledger(player_index, amount, reason, balance)
    local ledger = storage.ledger
    local id = ledger.next_id
    ledger.next_id = id + 1
    ledger.records[id] = {
        id = id,
        tick = game.tick,
        player_index = player_index,
        amount = amount,
        reason = reason,
        balance = balance,
    }

    while ledger.next_id - ledger.first_id > config.ledger_record_limit do
        ledger.records[ledger.first_id] = nil
        ledger.first_id = ledger.first_id + 1
    end
end

local function notify_balance_changed(player_index, balance)
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
            credit = config.initial_credit,
            created_tick = game.tick,
            last_seen_tick = game.tick,
        }
        storage.players[player_index] = account
    end
    if account.credit == nil then account.credit = config.initial_credit end
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
    append_ledger(player_index, amount, reason, next_balance)
    notify_balance_changed(player_index, next_balance)
    return true, next_balance
end

function M.transfer(from_index, to_index, amount, reason)
    if from_index == to_index then return false, 'same-account' end
    if not is_finite_integer(amount) or amount <= 0 then
        return false, 'invalid-amount'
    end

    local from = M.ensure_account(from_index)
    local to = M.ensure_account(to_index)
    if not is_finite_integer(from.credit) or from.credit < amount then
        return false, 'insufficient-credit'
    end
    if not is_finite_integer(to.credit) or to.credit < 0 then
        return false, 'invalid-balance'
    end

    local next_to = to.credit + amount
    if not is_finite_integer(next_to) then return false, 'invalid-result' end

    -- Validate both results before mutating either account, then commit the pair.
    from.credit = from.credit - amount
    to.credit = next_to
    append_ledger(from_index, -amount, reason or 'transfer-out', from.credit)
    append_ledger(to_index, amount, reason or 'transfer-in', to.credit)
    notify_balance_changed(from_index, from.credit)
    notify_balance_changed(to_index, to.credit)
    return true
end

function M.taxed_transfer(from_index, to_index, price, payout, reason)
    if not is_finite_integer(price) or price <= 0 then
        return false, 'invalid-amount'
    end
    if not is_finite_integer(payout) or payout < 0 or payout > price then
        return false, 'invalid-payout'
    end

    local buyer = M.ensure_account(from_index)
    if not is_finite_integer(buyer.credit) or buyer.credit < price then
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
    append_ledger(from_index, -price, reason, buyer.credit)
    if seller and payout > 0 then
        append_ledger(to_index, payout, reason, seller.credit)
    end
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
