local config = require('config')
local events = require('scripts.events')
local experience = require('scripts.experience')
local factions = require('scripts.factions')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

local function conversion_bucket_count()
    return math.max(1, math.floor(
        config.science_offline_conversion_ticks
            / config.science_conversion_ticks
    ))
end

local function conversion_buckets()
    local count = conversion_bucket_count()
    local buckets = storage.dropoff_conversion_buckets
    if type(buckets) ~= 'table' or #buckets ~= count then
        buckets = {}
        for index = 1, count do buckets[index] = {} end
        storage.dropoff_conversion_buckets = buckets
    end
    return buckets
end

local function conversion_bucket(player_index)
    return player_index % conversion_bucket_count() + 1
end

local function index_for_conversion(player_index)
    conversion_buckets()[conversion_bucket(player_index)][player_index] = true
end

local function unindex_for_conversion(player_index)
    conversion_buckets()[conversion_bucket(player_index)][player_index] = nil
end

local function same_position(record, surface_name, position)
    return record
        and record.surface == surface_name
        and record.x == position.x
        and record.y == position.y
end

local function records(player_index)
    state.ensure()
    local value = storage.dropoffs[player_index]
    if not value then
        value = {}
        storage.dropoffs[player_index] = value
    elseif value.surface then
        -- Normalize the former one-record shape when an existing save first
        -- uses configurable multiple drop-offs.
        value = {value}
        storage.dropoffs[player_index] = value
    end
    return value
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

local function resolve_record(player_index, record)
    local player = game.get_player(player_index)
    local surface = record and game.surfaces[record.surface]
    if not (player and surface and surface.valid) then return nil end
    local chest = surface.find_entity(
        config.linked_chest_name,
        {record.x, record.y}
    )
    if not (chest and chest.valid
            and chest.link_id == player_index
            and chest.force == player.force) then
        return nil
    end
    chest.operable = false
    return chest
end

local function compact_records(player_index)
    local list = records(player_index)
    for index = #list, 1, -1 do
        if not resolve_record(player_index, list[index]) then
            table.remove(list, index)
        end
    end
    return list
end

function M.ensure()
    state.ensure()
    local indexes = {}
    for player_index in pairs(storage.dropoffs) do
        indexes[#indexes + 1] = player_index
    end
    table.sort(indexes)
    for _, player_index in ipairs(indexes) do
        local list = compact_records(player_index)
        if #list == 0 then storage.dropoffs[player_index] = nil end
    end
    local buckets = {}
    for index = 1, conversion_bucket_count() do buckets[index] = {} end
    storage.dropoff_conversion_buckets = buckets
    for player_index, list in pairs(storage.dropoffs) do
        if #list > 0 then index_for_conversion(player_index) end
    end
end

local function placement_allowed(player, surface)
    local home_planet = factions.of_player(player)
    if not home_planet or player.force ~= factions.of_planet(home_planet) then
        return false
    end
    if surface.name == home_planet then return true end
    for _, planet_name in ipairs(config.public_planets) do
        if surface.name == planet_name then
            return not settings.get('personal_linked_chest_home_planet_only')
        end
    end
    if surfaces.hospice_planet(surface) then
        return settings.get('personal_linked_chest_allow_hospice')
    end
    if surfaces.property_planet(surface) then
        return settings.get('personal_linked_chest_allow_property')
    end
    return false
end

local function evict_oldest(player)
    local list = compact_records(player.index)
    local record = table.remove(list, 1)
    if not record then return false end
    local old = resolve_record(player.index, record)
    if old then
        local surface = old.surface
        local position = old.position
        local quality = old.quality.name
        old.destroy()
        give_wooden_chest(player, surface, position, quality)
        player.print({'un.dropoff-replaced'})
    end
    return old ~= nil
end

function M.enforce_limit()
    local limit = settings.get('personal_linked_chest_limit')
    local indexes = {}
    for player_index in pairs(storage.dropoffs) do
        indexes[#indexes + 1] = player_index
    end
    table.sort(indexes)
    for _, player_index in ipairs(indexes) do
        local player = game.get_player(player_index)
        if player then
            local list = compact_records(player_index)
            while #list > limit do
                evict_oldest(player)
                list = records(player_index)
            end
        end
    end
end

local function on_player_built(event)
    local entity = event.entity
    if not (entity and entity.valid
            and entity.name == config.wooden_chest_name) then
        return
    end
    local player = game.get_player(event.player_index)
    if not (player and entity.force == player.force
            and placement_allowed(player, entity.surface)) then
        return
    end
    local limit = settings.get('personal_linked_chest_limit')
    if limit <= 0 then return end

    local list = compact_records(player.index)
    while #list >= limit do
        evict_oldest(player)
        list = records(player.index)
    end

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
    list[#list + 1] = {
        surface = surface.name,
        x = position.x,
        y = position.y,
    }
    index_for_conversion(player.index)
    player.print({'un.dropoff-created-count', #list, limit})
end

local function forget_chest(entity)
    if not (entity and entity.valid
            and entity.name == config.linked_chest_name) then
        return false
    end
    local list = records(entity.link_id)
    for index = #list, 1, -1 do
        if same_position(list[index], entity.surface.name, entity.position) then
            table.remove(list, index)
            if #list == 0 then unindex_for_conversion(entity.link_id) end
            return true
        end
    end
    return false
end

local function on_mined(event)
    local entity = event.entity
    if not (entity and entity.valid
            and entity.name == config.linked_chest_name) then
        return
    end
    if not forget_chest(entity) then return end
    local quality = entity.quality.name
    event.buffer.remove{
        name = config.linked_chest_name,
        count = 1,
        quality = quality,
    }
    event.buffer.insert{
        name = config.wooden_chest_name,
        count = 1,
        quality = quality,
    }
end

local function remove_science_packs(inventory)
    local entries = inventory.get_contents()
    table.sort(entries, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.quality < b.quality
    end)
    local removed_entries = {}
    local total_items = 0
    for _, item in ipairs(entries) do
        if config.science_pack_experience[item.name] then
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
            end
        end
    end
    return removed_entries, total_items
end

function M.get_inventory(player)
    if not (player and player.valid) then return nil end
    local inventory = player.force.get_linked_inventory(
        config.linked_chest_name,
        player.index
    )
    if inventory and inventory.valid then return inventory end
    local list = compact_records(player.index)
    local chest = list[1] and resolve_record(player.index, list[1])
    inventory = chest and chest.valid
        and chest.get_inventory(defines.inventory.chest) or nil
    return inventory and inventory.valid and inventory or nil
end

function M.has_active_dropoff(player_index)
    return #compact_records(player_index) > 0
end

function M.active_count()
    state.ensure()
    local total = 0
    for player_index in pairs(storage.dropoffs) do
        total = total + #compact_records(player_index)
    end
    return total
end

function M.get_active_dropoff(player_index)
    local list = compact_records(player_index)
    return list[1] and resolve_record(player_index, list[1]) or nil
end

function M.clear_player_dropoff(player_index)
    local list = compact_records(player_index)
    for _, record in ipairs(list) do
        local chest = resolve_record(player_index, record)
        if chest then chest.destroy() end
    end
    storage.dropoffs[player_index] = nil
    unindex_for_conversion(player_index)
end

function M.purge_player(player_index)
    state.ensure()
    M.clear_player_dropoff(player_index)
    for _, entry in ipairs(factions.all()) do
        local inventory = entry.force.get_linked_inventory(
            config.linked_chest_name,
            player_index
        )
        if inventory and inventory.valid then inventory.clear() end
    end
end

function M.release_player_dropoff(player)
    local list = compact_records(player.index)
    for _, record in ipairs(list) do
        local chest = resolve_record(player.index, record)
        if chest then
            local quality = chest.quality.name
            chest.destroy()
            give_wooden_chest(
                player,
                player.physical_surface,
                player.physical_position,
                quality
            )
        end
    end
    storage.dropoffs[player.index] = nil
    unindex_for_conversion(player.index)
end

function M.clear_surface_dropoffs(surface_name)
    state.ensure()
    for player_index in pairs(storage.dropoffs) do
        local list = records(player_index)
        for index = #list, 1, -1 do
            local record = list[index]
            if record.surface == surface_name then
                local chest = resolve_record(player_index, record)
                if chest then chest.destroy() end
                table.remove(list, index)
            end
        end
        if #list == 0 then unindex_for_conversion(player_index) end
    end
end

local function convert_inventory(player, inventory)
    if not (inventory and inventory.valid) then return 0 end
    local removed, total_items = remove_science_packs(inventory)
    if total_items <= 0 then return 0 end
    experience.record(player.index, removed)
    return total_items
end

function M.convert_player(player)
    return convert_inventory(player, M.get_inventory(player))
end

local function notify_online_conversion(player, converted)
    if converted <= 0
            or not player.connected
            or not settings.get('science_conversion_notifications') then
        return
    end
    player.create_local_flying_text{
        text = {'un.science-converted-notification', converted},
        position = player.physical_position,
        surface = player.physical_surface,
        color = {r = 0.55, g = 1, b = 0.55},
        time_to_live = 180,
        speed = 0.5,
    }
end

events.on(defines.events.on_built_entity, on_player_built)
events.on(defines.events.on_player_mined_entity, on_mined)
events.on(defines.events.on_robot_mined_entity, on_mined)
events.on(defines.events.on_entity_died, function(event)
    forget_chest(event.entity)
end)

scheduler.every(config.science_conversion_ticks, function(event)
    for _, player in pairs(game.connected_players) do
        local converted = M.convert_player(player)
        notify_online_conversion(player, converted)
    end

    -- Offline linked inventories are checked less often and spread over the
    -- regular conversion passes. This avoids a ten-minute spike and never
    -- scans every offline player or every chest entity.
    local slots = conversion_bucket_count()
    local slot = math.floor(event.tick / config.science_conversion_ticks)
        % slots + 1
    local maximum_offline_ticks = config.science_offline_conversion_max_hours
        * config.ticks_per_hour
    local indexes = {}
    for player_index in pairs(conversion_buckets()[slot]) do
        indexes[#indexes + 1] = player_index
    end
    table.sort(indexes)
    for _, player_index in ipairs(indexes) do
        local player = game.get_player(player_index)
        local account = storage.players[player_index]
        local last_seen_tick = account and tonumber(account.last_seen_tick)
            or player and tonumber(player.last_online)
        if player and player.valid and not player.connected
                and last_seen_tick
                and game.tick - last_seen_tick >= 0
                and game.tick - last_seen_tick <= maximum_offline_ticks then
            M.convert_player(player)
        elseif not player or not player.valid
                or not storage.dropoffs[player_index]
                or #storage.dropoffs[player_index] == 0 then
            unindex_for_conversion(player_index)
        end
    end
end)

factions.on_switch_cleanup(function(player)
    M.release_player_dropoff(player)
end)

return M
