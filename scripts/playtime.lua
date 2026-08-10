local state = require('scripts.state')

local M = {}

local function account(player)
    state.ensure()
    local value = storage.players[player.index]
    if type(value) ~= 'table' then
        value = {}
        storage.players[player.index] = value
    end
    return value
end

-- Keep a monotonic total even if game.reset_time_played() also resets the
-- engine's per-player online_time counter in a future Factorio version.
function M.ticks(player)
    if not (player and player.valid) then return 0 end
    local value = account(player)
    local live = player.online_time or 0
    local previous = value.last_engine_online_ticks
    if previous == nil then
        value.total_online_ticks = math.max(value.total_online_ticks or 0, live)
    elseif live >= previous then
        value.total_online_ticks = (value.total_online_ticks or 0)
            + live - previous
    else
        value.total_online_ticks = (value.total_online_ticks or 0) + live
    end
    value.last_engine_online_ticks = live
    return value.total_online_ticks or 0
end

function M.snapshot_all()
    for _, player in pairs(game.players) do M.ticks(player) end
end

return M
