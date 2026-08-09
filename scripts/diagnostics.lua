local config = require('config')
local events = require('scripts.events')
local state = require('scripts.state')

local M = {}

local function command_player(command)
    if not command.player_index then return nil end
    return game.get_player(command.player_index)
end

local function reply(command, message)
    local player = command_player(command)
    if player then
        player.print(message)
    else
        localised_print(message)
    end
end

local function require_admin(command)
    local player = command_player(command)
    if player and not player.admin then
        player.print({'un.admin-only'})
        return false
    end
    return true
end

local function ensure_test_surface()
    local surface = game.surfaces[config.stage0_surface_name]
    if not (surface and surface.valid) then
        surface = game.create_surface(config.stage0_surface_name, {
            width = 64,
            height = 64,
            water = 0,
            peaceful_mode = true,
            no_enemies_mode = true,
        })
    end
    -- surface.clear(true) deletes all chunks. Generate the small laboratory
    -- again on every test run so linked-chest creation never depends on whether
    -- a clear test ran immediately beforehand.
    surface.request_to_generate_chunks({0, 0}, 1)
    surface.force_generate_chunk_requests()
    return surface
end

local function destroy_probe_chests(surface)
    for _, entity in pairs(surface.find_entities_filtered{
        name = config.linked_chest_name,
    }) do
        if entity.valid then entity.destroy() end
    end
end

local function create_probe_chest(surface, position, link_id)
    local chest = surface.create_entity{
        name = config.linked_chest_name,
        position = position,
        force = game.forces.player,
        raise_built = false,
    }
    if not (chest and chest.valid) then return nil end
    chest.link_id = link_id
    chest.operable = false
    chest.destructible = false
    chest.minable = false
    return chest
end

local function run_linked_inventory_test(command)
    state.ensure()
    if not prototypes.entity[config.linked_chest_name] then
        storage.stage0.linked_test = 'missing-prototype'
        reply(command, {'un.linked-missing'})
        return
    end

    local surface = ensure_test_surface()
    destroy_probe_chests(surface)

    local first = create_probe_chest(surface, {-2.5, 0.5}, config.stage0_link_id_a)
    local second = create_probe_chest(surface, {2.5, 0.5}, config.stage0_link_id_b)
    if not (first and second) then
        storage.stage0.linked_test = 'create-failed'
        reply(command, {'un.linked-create-failed'})
        return
    end

    local force = game.forces.player
    local direct = force.get_linked_inventory(config.linked_chest_name, config.stage0_link_id_a)
    local first_inventory = first.get_inventory(defines.inventory.chest)
    local separate_inventory = second.get_inventory(defines.inventory.chest)
    if not (direct and direct.valid and first_inventory and first_inventory.valid
            and separate_inventory and separate_inventory.valid) then
        storage.stage0.linked_test = 'inventory-missing'
        reply(command, {'un.linked-inventory-missing'})
        return
    end

    direct.clear()
    separate_inventory.clear()
    local inserted = direct.insert{name = 'iron-plate', count = 1}
    local separate_count = separate_inventory.get_item_count('iron-plate')

    second.link_id = config.stage0_link_id_a
    local relinked_inventory = second.get_inventory(defines.inventory.chest)
    local relinked_count = relinked_inventory and relinked_inventory.valid
        and relinked_inventory.get_item_count('iron-plate') or 0
    local direct_again = force.get_linked_inventory(
        config.linked_chest_name,
        config.stage0_link_id_a
    )

    local passed = inserted == 1
        and separate_count == 0
        and relinked_count == 1
        and direct_again
        and direct_again.valid
        and direct_again.get_item_count('iron-plate') == 1

    direct.clear()
    storage.stage0.linked_test = passed and 'passed' or 'failed'
    storage.stage0.linked_test_tick = game.tick
    reply(command, passed and {'un.linked-passed'} or {'un.linked-failed'})
end

local function run_clear_test(command)
    state.ensure()
    local surface = ensure_test_surface()
    storage.stage0.clear_test = 'pending'
    storage.stage0.clear_requested_tick = game.tick
    storage.stage0.clear_surface_index = surface.index
    surface.clear(true)
    reply(command, {'un.clear-requested'})
end

local function run_cleanup(command)
    state.ensure()
    local surface = game.surfaces[config.stage0_surface_name]
    if not (surface and surface.valid) then
        reply(command, {'un.cleanup-none'})
        return
    end

    for _, player in pairs(game.players) do
        if player.physical_surface == surface or player.surface == surface then
            reply(command, {'un.cleanup-player-present', player.name})
            return
        end
    end

    local queued = game.delete_surface(surface)
    if queued then
        storage.stage0.cleanup_requested_tick = game.tick
        reply(command, {'un.cleanup-queued'})
    else
        reply(command, {'un.cleanup-failed'})
    end
end

local function yes_no(value)
    return value and {'un.yes'} or {'un.no'}
end

local function print_status(command)
    state.ensure()
    local active = script.active_mods[config.space_age_mod_name] ~= nil
    local prototype_exists = prototypes.entity[config.linked_chest_name] ~= nil
    reply(command, {'un.status-header'})
    reply(command, {'un.status-space-age', yes_no(active)})
    reply(command, {'un.status-linked-prototype', yes_no(prototype_exists)})
    reply(command, {'un.status-linked-test', storage.stage0.linked_test or 'not-run'})
    reply(command, {'un.status-clear-test', storage.stage0.clear_test or 'not-run'})
end

local function on_command(command)
    if not require_admin(command) then return end
    local action = command.parameter and command.parameter:match('^%s*(%S+)') or 'status'
    if action == 'status' then
        print_status(command)
    elseif action == 'linked' then
        run_linked_inventory_test(command)
    elseif action == 'clear' then
        run_clear_test(command)
    elseif action == 'cleanup' then
        run_cleanup(command)
    else
        reply(command, {'un.command-stage0-usage'})
    end
end

events.on(defines.events.on_surface_cleared, function(event)
    state.ensure()
    if storage.stage0.clear_surface_index ~= event.surface_index then return end
    storage.stage0.clear_test = 'passed'
    storage.stage0.clear_completed_tick = event.tick
    storage.stage0.clear_surface_index = nil
    for _, player in pairs(game.connected_players) do
        if player.admin then player.print({'un.clear-passed'}) end
    end
end)

return M
