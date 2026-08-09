local config = require('config')
local events = require('scripts.events')
local stamina = require('scripts.stamina')

local M = {}

events.on(defines.events.on_player_died, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- Faction switching already charges its own stamina cost. Its pending
    -- record is installed before character.die(), so this synchronous death
    -- event can exempt exactly that death from the fast-respawn charge.
    local switching = storage.pending_faction_switches
        and storage.pending_faction_switches[player.index]
    if switching then
        player.ticks_to_respawn =
            config.normal_respawn_seconds * config.ticks_per_second
        return
    end

    if stamina.spend(player.index, config.fast_respawn_stamina_cost) then
        player.ticks_to_respawn =
            config.fast_respawn_seconds * config.ticks_per_second
    else
        player.ticks_to_respawn =
            config.normal_respawn_seconds * config.ticks_per_second
    end
end)

return M
