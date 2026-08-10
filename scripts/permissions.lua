local events = require('scripts.events')
local settings = require('scripts.settings')

local M = {}

local NEWCOMER_GROUP_NAME = 'un-newcomer'
local ESTABLISHED_GROUP_NAME = 'un-established'
local REQUIREMENT_KEY = 'deconstruction_min_online_hours'

local function get_group(name, allow_deconstruction)
    local group = game.permissions.get_group(name)
    if group then return group end
    group = game.permissions.create_group(name)
    if not group then return nil end
    group.set_allows_action(
        defines.input_action.deconstruct,
        allow_deconstruction
    )
    -- Cancelling an existing mark remains safe for newcomers.
    group.set_allows_action(defines.input_action.cancel_deconstruct, true)
    return group
end

local function groups()
    return get_group(NEWCOMER_GROUP_NAME, false),
        get_group(ESTABLISHED_GROUP_NAME, true)
end

function M.refresh_player(player, notify_unlock)
    if not (player and player.valid) then return false end
    local newcomer, established = groups()
    if not (newcomer and established) then return false end
    local unlocked = settings.online_requirement_met(player, REQUIREMENT_KEY)
    local target = unlocked and established or newcomer
    if player.permission_group == target then return false end
    local was_newcomer = player.permission_group == newcomer
    target.add_player(player)
    if notify_unlock and unlocked and was_newcomer then
        player.print({'un.deconstruction-unlocked'})
    end
    return true
end

function M.refresh_connected(notify_unlock)
    for _, player in pairs(game.connected_players) do
        M.refresh_player(player, notify_unlock)
    end
end

function M.ensure()
    groups()
    for _, player in pairs(game.players) do
        M.refresh_player(player, false)
    end
end

events.on(defines.events.on_player_created, function(event)
    M.refresh_player(game.get_player(event.player_index), false)
end)

events.on(defines.events.on_player_joined_game, function(event)
    M.refresh_player(game.get_player(event.player_index), false)
end)

events.on(defines.events.on_player_changed_surface, function(event)
    M.refresh_player(game.get_player(event.player_index), true)
end)

return M
