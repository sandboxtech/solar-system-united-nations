local config = require('config')
local economy = require('scripts.economy')
local state = require('scripts.state')

local M = {}

local MAX_SAFE_INTEGER = 9007199254740991

local function valid_amount(value)
    return type(value) == 'number'
        and value >= 0
        and value <= MAX_SAFE_INTEGER
        and value == math.floor(value)
end

local function bump_player_data_revision()
    storage.player_data_revision = (storage.player_data_revision or 0) + 1
end

local function merge_experience(target, source)
    if type(source) ~= 'table' or source == target then return target end
    for name, amount in pairs(source) do
        if type(name) == 'string' and valid_amount(amount) then
            local current = valid_amount(target[name]) and target[name] or 0
            target[name] = math.min(
                MAX_SAFE_INTEGER,
                math.max(current, amount)
            )
        end
    end
    return target
end

local function preserve_account_data(player_index, player_name)
    state.ensure()
    local account = storage.players[player_index]
    local old = type(account) == 'table' and account.science_consumed or nil
    local player = game.get_player(player_index)
    player_name = player_name
        or player and player.name
        or type(account) == 'table' and account.name
    if not player_name then
        if type(old) ~= 'table' then
            old = {}
            if type(account) == 'table' then account.science_consumed = old end
        end
        return old
    end

    local saved = storage.player_experience_by_name[player_name]
    if type(saved) ~= 'table' then
        saved = type(old) == 'table' and old or {}
        storage.player_experience_by_name[player_name] = saved
    else
        merge_experience(saved, old)
    end
    if type(account) == 'table' then account.science_consumed = nil end
    return saved
end

local function account_data(player_index)
    local account = economy.ensure_account(player_index)
    return preserve_account_data(player_index, account.name)
end

-- LuaPlayer indexes can change after game.remove_offline_players(). Preserve
-- the only durable part of an account under the stable player name first.
function M.preserve(player_index, player_name)
    return preserve_account_data(player_index, player_name)
end

function M.record(player_index, entries)
    local data = account_data(player_index)
    local changed = false
    for _, entry in ipairs(entries) do
        local count = tonumber(entry.count)
        if type(entry.name) == 'string' and valid_amount(count) and count > 0 then
            local current = valid_amount(data[entry.name])
                and data[entry.name] or 0
            local next_amount = math.min(MAX_SAFE_INTEGER, current + count)
            if next_amount ~= current then
                data[entry.name] = next_amount
                changed = true
            end
        end
    end
    if changed then bump_player_data_revision() end
end

function M.get(player_index)
    return account_data(player_index)
end

function M.amount(player_index, name)
    local amount = account_data(player_index)[name]
    return valid_amount(amount) and amount or 0
end

function M.spend(player_index, name, amount)
    if type(amount) ~= 'number' or amount < 0
            or amount > MAX_SAFE_INTEGER or amount ~= math.floor(amount) then
        return false
    end
    local data = account_data(player_index)
    local available = valid_amount(data[name]) and data[name] or 0
    if available < amount then return false end
    data[name] = available - amount
    if amount ~= 0 then bump_player_data_revision() end
    return true
end

function M.contribution(amount)
    if amount < 1 then return 0 end
    return math.floor(math.log(amount, 10)) + 1
end

function M.next_threshold(amount)
    if amount < 1 then return 1 end
    return math.min(MAX_SAFE_INTEGER, 10 ^ M.contribution(amount))
end

function M.total_level(player_index)
    local data = account_data(player_index)
    local level = 0
    for _, name in ipairs(config.science_pack_order) do
        local amount = valid_amount(data[name]) and data[name] or 0
        level = level + M.contribution(amount)
    end
    return level
end

function M.total_consumed(player_index)
    local data = account_data(player_index)
    local total = 0
    for _, name in ipairs(config.science_pack_order) do
        local amount = valid_amount(data[name]) and data[name] or 0
        total = math.min(MAX_SAFE_INTEGER, total + amount)
    end
    return total
end

return M
