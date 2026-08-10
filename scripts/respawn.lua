local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')
local stamina = require('scripts.stamina')

local M = {}

local function entity_player(entity)
    if not (entity and entity.valid) then return nil end
    if entity.type == 'character' then return entity.player end
    local ok, driver = pcall(function() return entity.get_driver() end)
    if not ok or not driver then return nil end
    if driver.object_name == 'LuaPlayer' then return driver end
    if driver.valid and driver.type == 'character' then return driver.player end
    return nil
end

local function broadcast_player_kill(victim, cause)
    local killer = entity_player(cause)
    if not (killer and killer.valid) or killer.index == victim.index then return end
    game.print({
        'un.player-killed-broadcast',
        killer.name,
        factions.display_name(factions.of_player(killer)),
        victim.name,
        factions.display_name(factions.of_player(victim)),
    })
end

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

    broadcast_player_kill(player, event.cause)

    if stamina.spend(player.index, config.fast_respawn_stamina_cost) then
        player.ticks_to_respawn =
            config.fast_respawn_seconds * config.ticks_per_second
    else
        player.ticks_to_respawn =
            config.normal_respawn_seconds * config.ticks_per_second
    end
end)

return M
