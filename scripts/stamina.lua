local config = require('config')
local economy = require('scripts.economy')

local M = {}

local function advance(player_index)
    local account = economy.ensure_account(player_index)
    if account.stamina == nil then
        account.stamina = config.stamina_max
        account.stamina_tick = game.tick
        return account
    end
    if account.stamina_tick == nil then account.stamina_tick = game.tick end
    if account.stamina >= config.stamina_max then
        account.stamina = config.stamina_max
        account.stamina_tick = game.tick
        return account
    end
    local seconds = math.floor(
        math.max(0, game.tick - account.stamina_tick)
            / config.ticks_per_second
    )
    if seconds > 0 then
        account.stamina = math.min(
            config.stamina_max,
            account.stamina + seconds * config.stamina_per_second
        )
        account.stamina_tick = account.stamina >= config.stamina_max
            and game.tick
            or account.stamina_tick + seconds * config.ticks_per_second
    end
    return account
end

function M.get(player_index)
    return advance(player_index).stamina
end

function M.spend(player_index, amount)
    if type(amount) ~= 'number' or amount < 0 or amount ~= math.floor(amount) then
        return false
    end
    local account = advance(player_index)
    if account.stamina < amount then return false end
    account.stamina = account.stamina - amount
    account.stamina_tick = game.tick
    return true
end

return M
