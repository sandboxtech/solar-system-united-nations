local config = require('config')
local events = require('scripts.events')

local M = {}

local function selected_record(player, record)
    if not (record and record.valid) then return nil end
    if record.type == 'blueprint-book' then
        local ok, selected = pcall(function()
            return record.get_selected_record(player)
        end)
        return ok and selected or nil
    end
    return record
end

local function blueprint_data(record)
    if not (record and record.valid) then return nil end
    local ok, setup, entities, tiles = pcall(function()
        if not record.is_blueprint_setup() then return false end
        return true,
            record.get_blueprint_entities() or {},
            record.get_blueprint_tiles() or {}
    end)
    if not ok or not setup then return nil end
    return entities, tiles
end

local function violation(record)
    local entities, tiles = blueprint_data(record)
    if not entities then return nil end
    if #entities > config.blueprint_max_entities then
        return 'entities', #entities, config.blueprint_max_entities
    end
    if #tiles > config.blueprint_max_tiles then
        return 'tiles', #tiles, config.blueprint_max_tiles
    end
    local min_x, max_x, min_y, max_y
    local function include(position)
        if not position then return end
        local x = position.x or position[1]
        local y = position.y or position[2]
        if not (x and y) then return end
        min_x = not min_x and x or math.min(min_x, x)
        max_x = not max_x and x or math.max(max_x, x)
        min_y = not min_y and y or math.min(min_y, y)
        max_y = not max_y and y or math.max(max_y, y)
    end
    for _, entity in ipairs(entities) do include(entity.position) end
    for _, tile in ipairs(tiles) do include(tile.position) end
    local width = min_x and math.floor(max_x - min_x + 1) or 0
    local height = min_y and math.floor(max_y - min_y + 1) or 0
    if width > config.blueprint_max_span or height > config.blueprint_max_span then
        return 'span', math.max(width, height), config.blueprint_max_span
    end
    return nil
end

local function warn(player, kind, actual, limit)
    player.print({'un.blueprint-too-large-' .. kind, actual, limit})
end

local function check_cursor(player, clear_cursor)
    if not (player and player.valid) or player.admin then return false end
    local record = selected_record(player, player.cursor_record)
    local kind, actual, limit = violation(record)
    if not kind then return false end
    if clear_cursor then player.clear_cursor() end
    warn(player, kind, actual, limit)
    return true
end

events.on(defines.events.on_player_setup_blueprint, function(event)
    local player = game.get_player(event.player_index)
    if not player or player.admin then return end
    local width = math.ceil(event.area.right_bottom.x - event.area.left_top.x)
    local height = math.ceil(event.area.right_bottom.y - event.area.left_top.y)
    if width > config.blueprint_max_span or height > config.blueprint_max_span then
        local target = event.record
        if target and target.valid then target.clear_blueprint() end
        warn(player, 'span', math.max(width, height), config.blueprint_max_span)
        return
    end
    local target = event.record
    local kind, actual, limit = violation(target)
    if kind then
        if target and target.valid then target.clear_blueprint() end
        warn(player, kind, actual, limit)
    end
end)

events.on(defines.events.on_player_configured_blueprint, function(event)
    check_cursor(game.get_player(event.player_index), true)
end)

events.on(defines.events.on_player_cursor_stack_changed, function(event)
    check_cursor(game.get_player(event.player_index), true)
end)

events.on(defines.events.on_pre_build, function(event)
    check_cursor(game.get_player(event.player_index), true)
end)

return M
