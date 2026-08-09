local config = require('config')
local economy = require('scripts.economy')
local settings = require('scripts.settings')

local M = {}

local function command_player(command)
    return command.player_index and game.get_player(command.player_index) or nil
end

local function friend_table(player_index)
    local account = economy.ensure_account(player_index)
    if type(account.friends) ~= 'table' then account.friends = {} end
    return account.friends
end

local function friend_count(friends)
    local count = 0
    for _, enabled in pairs(friends) do
        if enabled then count = count + 1 end
    end
    return count
end

local function target_player(name)
    name = (name or ''):match('^%s*(.-)%s*$')
    if name == '' then return nil end
    local player = game.get_player(name)
    if player and player.valid then return player end
    return nil
end

function M.are_mutual(first_index, second_index)
    if not (first_index and second_index) or first_index == second_index then
        return false
    end
    return friend_table(first_index)[second_index] == true
        and friend_table(second_index)[first_index] == true
end

function M.is_friend(player_index, target_index)
    return friend_table(player_index)[target_index] == true
end

function M.add_friend(player_index, target_index)
    if player_index == target_index then return false, 'self' end
    local target = game.get_player(target_index)
    if not (target and target.valid) then return false, 'missing' end
    local friends = friend_table(player_index)
    if friends[target_index] then return false, 'already' end
    if friend_count(friends) >= settings.get('friend_limit') then
        return false, 'limit'
    end
    friends[target_index] = true
    return true, M.are_mutual(player_index, target_index)
end

function M.remove_friend(player_index, target_index)
    local friends = friend_table(player_index)
    if not friends[target_index] then return false, 'not-added' end
    friends[target_index] = nil
    return true
end

function M.remove_offline_friends(player_index)
    local friends = friend_table(player_index)
    local removed = 0
    for target_index, enabled in pairs(friends) do
        local target = game.get_player(target_index)
        if enabled and not (target and target.valid and target.connected) then
            friends[target_index] = nil
            removed = removed + 1
        end
    end
    return removed
end

function M.remove_player(player_index)
    if not storage.players then return end
    for _, account in pairs(storage.players) do
        if type(account) == 'table' and type(account.friends) == 'table' then
            account.friends[player_index] = nil
        end
    end
end

local function transfer_command(command)
    local player = command_player(command)
    if not player then
        localised_print({'un.transfer-player-only'})
        return
    end
    local name, amount_text = (command.parameter or ''):match(
        '^%s*(.-)%s+(%S+)%s*$'
    )
    local target = target_player(name)
    local amount = tonumber(amount_text)
    if not target then
        player.print({'un.player-not-found'})
        return
    end
    if not amount or amount ~= math.floor(amount)
            or amount < config.transfer_min_amount then
        player.print({'un.transfer-invalid-amount', config.transfer_min_amount})
        return
    end
    local fee = math.max(
        config.transfer_min_fee,
        math.ceil(amount * config.transfer_fee_rate)
    )
    local reason = 'credit-transfer:' .. player.index .. ':' .. target.index
    local ok, err = economy.transfer(
        player.index,
        target.index,
        amount,
        fee,
        reason
    )
    if not ok then
        if err == 'same-account' then
            player.print({'un.transfer-self'})
        elseif err == 'insufficient-credit' then
            player.print({'un.property-error-credit'})
        else
            player.print({'un.transfer-failed'})
        end
        return
    end
    player.print({'un.transfer-sent', amount, target.name, fee})
    if target.connected then
        target.print({'un.transfer-received', amount, player.name})
    end
end

commands.add_command('un-transfer', {'un.transfer-command-help'}, transfer_command)

return M
