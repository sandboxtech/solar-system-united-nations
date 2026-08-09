local config = require('config')
local economy = require('scripts.economy')

local M = {}

local function account_data(player_index)
    local account = economy.ensure_account(player_index)
    if account.science_consumed == nil then account.science_consumed = {} end
    return account.science_consumed
end

function M.record(player_index, entries)
    local data = account_data(player_index)
    for _, entry in ipairs(entries) do
        data[entry.name] = (data[entry.name] or 0) + entry.count
    end
end

function M.get(player_index)
    return account_data(player_index)
end

function M.contribution(amount)
    if amount < 1 then return 0 end
    return math.floor(math.log(amount, 10)) + 1
end

function M.next_threshold(amount)
    if amount < 1 then return 1 end
    return 10 ^ M.contribution(amount)
end

function M.total_level(player_index)
    local data = account_data(player_index)
    local level = 0
    for _, name in ipairs(config.science_pack_order) do
        level = level + M.contribution(data[name] or 0)
    end
    return level
end

function M.total_consumed(player_index)
    local data = account_data(player_index)
    local total = 0
    for _, name in ipairs(config.science_pack_order) do
        total = total + (data[name] or 0)
    end
    return total
end

return M
