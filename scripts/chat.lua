local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')

local M = {}

local function colored_player_name(player)
    local color = player.chat_color
    return {
        '',
        string.format(
            '[color=%.3f,%.3f,%.3f]',
            color.r,
            color.g,
            color.b
        ),
        player.name,
        '[/color]',
    }
end

events.on(defines.events.on_console_chat, function(event)
    if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local source_planet = factions.of_player(player)
    if not source_planet then return end
    local message = {
        'un.faction-chat-message',
        factions.chat_display_name(source_planet),
        colored_player_name(player),
        event.message,
    }
    -- Factorio already delivers the original line inside the sender's force.
    -- Forward one labelled copy to every other faction so cross-force chat is
    -- audible without duplicating the message for the sender's own faction.
    for _, target_planet in ipairs(config.public_planets) do
        if target_planet ~= source_planet then
            local force = factions.of_planet(target_planet)
            if force and force.valid then
                force.print(message, {
                    skip = defines.print_skip.never,
                })
            end
        end
    end
end)

return M
