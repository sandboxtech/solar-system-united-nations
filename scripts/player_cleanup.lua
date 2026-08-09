local config = require('config')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')
local properties = require('scripts.properties')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local ships = require('scripts.ships')
local social = require('scripts.social')
local state = require('scripts.state')

local M = {}

local function clean_ledger(player_index)
    local ledger = storage.ledger
    if not (ledger and ledger.records) then return end
    for id = ledger.first_id, ledger.next_id - 1 do
        local record = ledger.records[id]
        if record then
            local from, to = (record.reason or ''):match(
                '^credit%-transfer:(%d+):(%d+)$'
            )
            if record.player_index == player_index
                    or tonumber(from) == player_index
                    or tonumber(to) == player_index then
                ledger.records[id] = nil
            end
        end
    end
end

local function release_assets(player_index)
    state.ensure()
    properties.release_owner(player_index)
    linked_inventory.clear_player_dropoff(player_index)
    ships.remove_owner(player_index)
    social.remove_player(player_index)
end

local function erase_scenario_account(player_index)
    state.ensure()
    clean_ledger(player_index)
    storage.players[player_index] = nil
end

local function candidate()
    local threshold = settings.get('cleanup_idle_hours') * config.ticks_per_hour
    local candidates = {}
    for _, player in pairs(game.players) do
        local account = storage.players[player.index]
        local last_seen = account and account.last_seen_tick
            or player.last_online
            or game.tick
        if not player.connected
                and (not player.admin or config.player_cleanup_admins)
                and game.tick - last_seen >= threshold then
            candidates[#candidates + 1] = {
                player = player,
                last_seen = last_seen,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.last_seen ~= b.last_seen then return a.last_seen < b.last_seen end
        return a.player.index < b.player.index
    end)
    return candidates[1] and candidates[1].player or nil
end

local function check_one()
    state.ensure()
    local player = candidate()
    if not player then return end
    local index = player.index
    local name = player.name
    release_assets(index)
    local ok, err = pcall(function()
        game.remove_offline_players({index})
    end)
    if ok then
        game.print({'un.player-cleaned', name, settings.get('cleanup_idle_hours')})
    else
        log('[un] failed to remove offline player ' .. name .. ': ' .. tostring(err))
    end
end

events.on(defines.events.on_pre_player_removed, function(event)
    release_assets(event.player_index)
end)

events.on(defines.events.on_player_removed, function(event)
    erase_scenario_account(event.player_index)
end)

scheduler.every(config.player_cleanup_check_ticks, check_one)

return M
