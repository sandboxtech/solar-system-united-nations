local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local experience = require('scripts.experience')
local factions = require('scripts.factions')
local scheduler = require('scripts.scheduler')
local state = require('scripts.state')

local M = {}

local function same_position(record, surface_name, position)
    return record
        and record.surface == surface_name
        and record.x == position.x
        and record.y == position.y
end

local function give_wooden_chest(player, surface, position, quality)
    local stack = {
        name = config.wooden_chest_name,
        count = 1,
        quality = quality or 'normal',
    }
    local inserted = player.insert(stack)
    if inserted == 1 then return true end
    surface.spill_item_stack{
        position = position,
        stack = stack,
        enable_looted = true,
        force = player.force,
    }
    player.print({'un.dropoff-refund-spilled'})
    return false
end

local function resolve_record(player_index)
    state.ensure()
    local record = storage.dropoffs[player_index]
    if not record then return nil end
    if record.surface ~= 'nauvis' then return nil end
    local surface = game.surfaces[record.surface]
    if not (surface and surface.valid) then return nil end
    local chest = surface.find_entity(
        config.linked_chest_name,
        {record.x, record.y}
    )
    local player = game.get_player(player_index)
    if not (chest and chest.valid
            and player
            and chest.link_id == player_index
            and chest.force == player.force) then
        return nil
    end
    return chest
end

local function evict_previous(player, new_surface_name, new_position)
    local record = storage.dropoffs[player.index]
    if not record then return false end

    local old = resolve_record(player.index)
    if old and not same_position(record, new_surface_name, new_position) then
        local surface = old.surface
        local position = old.position
        local quality = old.quality.name
        old.destroy()
        give_wooden_chest(player, surface, position, quality)
        player.print({'un.dropoff-replaced'})
    end
    storage.dropoffs[player.index] = nil
    return old ~= nil
end

local function on_player_built(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    if entity.name ~= config.wooden_chest_name then return end
    if entity.surface.name ~= 'nauvis' then return end

    state.ensure()
    evict_previous(player, entity.surface.name, entity.position)

    local surface = entity.surface
    local position = entity.position
    local force = entity.force
    local quality = entity.quality.name
    entity.destroy()

    local chest = surface.create_entity{
        name = config.linked_chest_name,
        position = position,
        force = force,
        quality = quality,
        player = player.index,
        raise_built = false,
    }
    if not (chest and chest.valid) then
        give_wooden_chest(player, surface, position, quality)
        player.print({'un.dropoff-create-failed'})
        return
    end

    chest.link_id = player.index
    chest.operable = false
    storage.dropoffs[player.index] = {
        surface = surface.name,
        x = position.x,
        y = position.y,
    }
    player.print({'un.dropoff-created'})
end

local function forget_chest(entity)
    if not (entity and entity.valid and entity.name == config.linked_chest_name) then
        return
    end
    state.ensure()
    local owner_index = entity.link_id
    local record = storage.dropoffs[owner_index]
    if same_position(record, entity.surface.name, entity.position) then
        storage.dropoffs[owner_index] = nil
    end
end

local function on_player_mined(event)
    local entity = event.entity
    if not (entity and entity.valid and entity.name == config.linked_chest_name) then
        return
    end
    forget_chest(entity)

    local quality = entity.quality.name
    local removed = event.buffer.remove{
        name = config.linked_chest_name,
        count = 1,
        quality = quality,
    }
    if removed > 0 then
        event.buffer.insert{
            name = config.wooden_chest_name,
            count = removed,
            quality = quality,
        }
    end
end

local function appraise_and_remove(inventory)
    local entries = inventory.get_contents()
    table.sort(entries, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.quality < b.quality
    end)

    local removed_entries = {}
    local total_items = 0
    local total_credit = 0
    for _, item in ipairs(entries) do
        local base = config.science_pack_credit[item.name]
        if base then
            local removed = inventory.remove{
                name = item.name,
                count = item.count,
                quality = item.quality,
            }
            if removed > 0 then
                removed_entries[#removed_entries + 1] = {
                    name = item.name,
                    quality = item.quality,
                    count = removed,
                }
                total_items = total_items + removed
                total_credit = total_credit + removed * base
            end
        end
    end
    return removed_entries, total_items, total_credit
end

local function refund(inventory, entries)
    for _, item in ipairs(entries) do
        local inserted = inventory.insert(item)
        if inserted ~= item.count then
            log('[un] failed to refund linked inventory item: ' .. item.name)
        end
    end
end

function M.get_inventory(player)
    return player.force.get_linked_inventory(
        config.linked_chest_name,
        player.index
    )
end

function M.has_active_dropoff(player_index)
    return resolve_record(player_index) ~= nil
end

function M.get_active_dropoff(player_index)
    return resolve_record(player_index)
end

function M.clear_player_dropoff(player_index)
    state.ensure()
    local chest = resolve_record(player_index)
    if chest and chest.valid then chest.destroy() end
    storage.dropoffs[player_index] = nil
end

function M.release_player_dropoff(player)
    state.ensure()
    local chest = resolve_record(player.index)
    if chest and chest.valid then
        local quality = chest.quality.name
        chest.destroy()
        give_wooden_chest(
            player,
            player.physical_surface,
            player.physical_position,
            quality
        )
    end
    storage.dropoffs[player.index] = nil
end

function M.clear_surface_dropoffs(surface_name)
    state.ensure()
    local indexes = {}
    for player_index, record in pairs(storage.dropoffs) do
        if record.surface == surface_name then indexes[#indexes + 1] = player_index end
    end
    table.sort(indexes)
    for _, player_index in ipairs(indexes) do
        M.clear_player_dropoff(player_index)
    end
end

local function convert_inventory(player, inventory, reason)
    if not (inventory and inventory.valid) then return 0, 0 end
    local removed, total_items, total_credit = appraise_and_remove(inventory)
    if total_credit <= 0 then return 0, 0 end

    local ok = economy.change(player.index, total_credit, reason)
    if not ok then
        refund(inventory, removed)
        return 0, 0
    end

    local account = economy.ensure_account(player.index)
    account.last_science_sale = {
        tick = game.tick,
        items = total_items,
        credit = total_credit,
    }
    experience.record(player.index, removed)
    return total_items, total_credit
end

function M.convert_player(player)
    return convert_inventory(
        player,
        M.get_inventory(player),
        'science-sale'
    )
end

function M.convert_main_inventory(player)
    local inventory = player and player.get_main_inventory()
    return convert_inventory(
        player,
        inventory,
        'backpack-science-sale'
    )
end

events.on(defines.events.on_built_entity, on_player_built)
events.on(defines.events.on_player_mined_entity, on_player_mined)
events.on(defines.events.on_entity_died, function(event)
    forget_chest(event.entity)
end)

scheduler.every(config.science_conversion_ticks, function()
    for _, player in pairs(game.connected_players) do
        M.convert_player(player)
    end
end)

factions.on_switch_cleanup(function(player)
    M.release_player_dropoff(player)
end)

return M
