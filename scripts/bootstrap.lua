local config = require('config')
local factions = require('scripts.factions')
local gui = require('scripts.gui')
local permissions = require('scripts.permissions')
local properties = require('scripts.properties')
local restrictions = require('scripts.restrictions')
local ships = require('scripts.ships')
local disasters = require('scripts.disasters')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')
local technology_decay = require('scripts.technology_decay')

local M = {}

local function run(repair)
    state.ensure()
    factions.ensure()
    for _, name in ipairs(config.public_planets) do
        surfaces.ensure_hospice(name)
    end
    disasters.ensure()
    surfaces.sync_all_hospice_environments()
    technology_decay.ensure()
    properties.ensure()
    permissions.ensure()
    if repair then restrictions.repair() else restrictions.ensure() end
    ships.ensure()
    surfaces.sync_all_property_environments()
    gui.ensure_all()
end

function M.run()
    run(false)
end

local function command_reply(command, message)
    local player = command.player_index and game.get_player(command.player_index)
    if player then player.print(message) else localised_print(message) end
end

local function repair_command(command)
    local player = command.player_index and game.get_player(command.player_index)
    if player and not player.admin then
        player.print({'un.admin-only'})
        return
    end
    run(true)
    command_reply(command, {'un.repair-state-finished'})
end

commands.add_command(
    'un-repair-state',
    {'un.repair-state-command-help'},
    repair_command
)

return M
