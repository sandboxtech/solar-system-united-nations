local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local factions = require('scripts.factions')
local scheduler = require('scripts.scheduler')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

local FRAME_NAME = 'un_market_trade_box_frame'
local PRICE_FIELD_NAME = 'un_market_trade_box_price'
local SAVE_BUTTON_NAME = 'un_market_trade_box_save'
local REMOVE_BUTTON_NAME = 'un_market_trade_box_remove'
local REQUESTER_NAME = 'requester-chest'
local PROVIDER_NAME = 'active-provider-chest'
local MAX_SAFE_INTEGER = 9007199254740991

local item_specs = {}
for _, spec in ipairs(config.market_items or {}) do
    assert(type(spec.base_price) == 'number' and spec.base_price > 0,
        'market base_price must be greater than zero: ' .. tostring(spec.name))
    item_specs[spec.name] = spec
end
assert(config.market_empty_price_multiplier > 1,
    'market_empty_price_multiplier must be greater than one')

local function valid_number(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function box_mode(entity)
    if not (entity and entity.valid) then return nil end
    if entity.name == REQUESTER_NAME then return 'buy' end
    if entity.name == PROVIDER_NAME then return 'sell' end
    return nil
end

local function initial_stock(spec)
    return math.max(1, math.floor(
        config.market_initial_stock_value / spec.base_price
    ))
end

local function initial_market()
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        result[spec.name] = initial_stock(spec)
    end
    return result
end

local function ensure_curve()
    if storage.market_curve_version == config.market_curve_version then return end
    storage.local_markets = {}
    storage.market_curve_version = config.market_curve_version
end

local function market_for_force(force_name)
    ensure_curve()
    local market = storage.local_markets[force_name]
    if type(market) ~= 'table' then
        market = initial_market()
        storage.local_markets[force_name] = market
    end
    for _, spec in ipairs(config.market_items or {}) do
        if type(market[spec.name]) ~= 'number' or market[spec.name] < 0 then
            market[spec.name] = initial_stock(spec)
        end
    end
    return market
end

local function rebuild_order()
    local order = {}
    for unit_number, record in pairs(storage.market_trade_boxes) do
        if type(unit_number) == 'number' and type(record) == 'table' then
            order[#order + 1] = unit_number
        end
    end
    table.sort(order)
    storage.market_trade_order = order
    storage.market_trade_cursor = math.min(
        math.max(1, tonumber(storage.market_trade_cursor) or 1),
        math.max(1, #order)
    )
end

function M.ensure()
    state.ensure()
    ensure_curve()
    for _, entry in ipairs(factions.all()) do
        market_for_force(entry.force.name)
    end
    for unit_number, record in pairs(storage.market_trade_boxes) do
        local entity = game.get_entity_by_unit_number(unit_number)
        if not (entity and entity.valid and box_mode(entity) == record.mode
                and entity.force.name == record.force_name
                and game.get_player(record.owner_index)) then
            storage.market_trade_boxes[unit_number] = nil
        end
    end
    rebuild_order()
end

local function curve_exponent(spec, stock)
    local stock_at_base_price = initial_stock(spec)
    return (stock_at_base_price - stock) / stock_at_base_price
end

local function spot_price(spec, stock)
    return spec.base_price * config.market_empty_price_multiplier
        ^ curve_exponent(spec, stock)
end

local function integral_scale(spec)
    return spec.base_price * initial_stock(spec)
        / math.log(config.market_empty_price_multiplier)
end

local function buy_cost(spec, stock, count)
    if count <= 0 or count > stock then return nil end
    local raw = integral_scale(spec) * (
        config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock - count)
        - config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock)
    )
    if not valid_number(raw) or raw > MAX_SAFE_INTEGER then return nil end
    return math.max(1, math.ceil(raw))
end

local function sell_revenue(spec, stock, count)
    if count <= 0 then return nil end
    local raw = integral_scale(spec) * (
        config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock)
        - config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock + count)
    )
    if not valid_number(raw) or raw > MAX_SAFE_INTEGER then return nil end
    return math.floor(raw)
end

local function unregister(unit_number)
    if not storage.market_trade_boxes[unit_number] then return false end
    storage.market_trade_boxes[unit_number] = nil
    rebuild_order()
    return true
end

local function validate_record(unit_number, record)
    local entity = game.get_entity_by_unit_number(unit_number)
    local owner = game.get_player(record.owner_index)
    if not (entity and entity.valid and owner and owner.valid
            and box_mode(entity) == record.mode
            and entity.force.name == record.force_name
            and owner.force == entity.force
            and surfaces.context_planet(entity.surface)
                == factions.planet_of_force(entity.force)) then
        unregister(unit_number)
        return nil
    end
    return entity, owner
end

local function targeted_counts(point)
    local counts = {}
    for _, item in ipairs(point.targeted_items_deliver or {}) do
        if item.quality == 'normal' then
            counts[item.name] = (counts[item.name] or 0) + item.count
        end
    end
    return counts
end

local function requested_counts(entity)
    local point = entity.get_logistic_point(
        defines.logistic_member_index.logistic_container
    )
    if not (point and point.valid and point.enabled) then return {} end
    local requested = {}
    for _, filter in ipairs(point.filters or {}) do
        if filter.name and item_specs[filter.name]
                and (not filter.quality or filter.quality == 'normal') then
            requested[filter.name] = math.max(
                requested[filter.name] or 0,
                math.max(0, math.floor(filter.count or 0))
            )
        end
    end
    local targeted = targeted_counts(point)
    for name, count in pairs(requested) do
        requested[name] = math.max(0, count - (targeted[name] or 0))
    end
    return requested
end

local function max_buy_count(spec, stock, limit, max_price, balance)
    local low, high = 0, math.min(stock, limit)
    while low < high do
        local middle = math.floor((low + high + 1) / 2)
        local final_price = spot_price(spec, stock - middle)
        local cost = buy_cost(spec, stock, middle)
        if cost and cost <= balance and final_price <= max_price
                and cost <= math.floor(max_price * middle) then
            low = middle
        else
            high = middle - 1
        end
    end
    return low
end

local function process_buy_box(entity, owner, record)
    local inventory = entity.get_inventory(defines.inventory.chest)
    if not (inventory and inventory.valid) then return end
    local market = market_for_force(record.force_name)
    local requested = requested_counts(entity)
    local left = config.market_max_items_per_trade
    local specs = config.market_items or {}
    local spec_count = #specs
    if spec_count == 0 then return end
    local start = math.min(math.max(1, record.item_cursor or 1), spec_count)
    for offset = 0, spec_count - 1 do
        if left <= 0 then break end
        local index = (start + offset - 1) % spec_count + 1
        local spec = specs[index]
        local wanted = requested[spec.name] or 0
        local present = inventory.get_item_count{
            name = spec.name,
            quality = 'normal',
        }
        local missing = math.max(0, wanted - present)
        if missing > 0 then
            local insertable = inventory.get_insertable_count{
                name = spec.name,
                quality = 'normal',
            }
            local stock = market[spec.name]
            local limit = math.min(missing, insertable, left)
            local balance = economy.get_balance(owner.index)
            local count = max_buy_count(
                spec, stock, limit, record.price_limit, balance
            )
            if count > 0 then
                local cost = buy_cost(spec, stock, count)
                local inserted = inventory.insert{
                    name = spec.name,
                    count = count,
                    quality = 'normal',
                }
                if inserted == count then
                    local paid = economy.change(owner.index, -cost, 'market-buy')
                    if paid then
                        market[spec.name] = stock - count
                        record.traded = (record.traded or 0) + count
                        record.coins = (record.coins or 0) + cost
                        record.item_cursor = index % spec_count + 1
                        return
                    else
                        inventory.remove{
                            name = spec.name,
                            count = count,
                            quality = 'normal',
                        }
                    end
                elseif inserted > 0 then
                    inventory.remove{
                        name = spec.name,
                        count = inserted,
                        quality = 'normal',
                    }
                end
            end
        end
    end
end

local function max_sell_count(spec, stock, limit, min_price)
    local low, high = 0, limit
    while low < high do
        local middle = math.floor((low + high + 1) / 2)
        local revenue = sell_revenue(spec, stock, middle)
        if spot_price(spec, stock + middle) >= min_price
                and revenue and revenue >= math.ceil(min_price * middle) then
            low = middle
        else
            high = middle - 1
        end
    end
    return low
end

local function process_sell_box(entity, owner, record)
    local inventory = entity.get_inventory(defines.inventory.chest)
    if not (inventory and inventory.valid) then return end
    local market = market_for_force(record.force_name)
    local left = config.market_max_items_per_trade
    local specs = config.market_items or {}
    local spec_count = #specs
    if spec_count == 0 then return end
    local start = math.min(math.max(1, record.item_cursor or 1), spec_count)
    local point = entity.get_logistic_point(
        defines.logistic_member_index.logistic_container
    )
    local targeted = {}
    if point and point.valid then
        for _, item in ipairs(point.targeted_items_pickup or {}) do
            if item.quality == 'normal' then
                targeted[item.name] = (targeted[item.name] or 0) + item.count
            end
        end
    end
    for offset = 0, spec_count - 1 do
        if left <= 0 then break end
        local index = (start + offset - 1) % spec_count + 1
        local spec = specs[index]
        local available = inventory.get_item_count{
            name = spec.name,
            quality = 'normal',
        } - (targeted[spec.name] or 0)
        available = math.max(0, available)
        local stock = market[spec.name]
        local count = max_sell_count(
            spec, stock, math.min(available, left), record.price_limit
        )
        if count > 0 then
            local revenue = sell_revenue(spec, stock, count)
            local removed = inventory.remove{
                name = spec.name,
                count = count,
                quality = 'normal',
            }
            if removed == count then
                local paid = economy.change(owner.index, revenue, 'market-sell')
                if paid then
                    market[spec.name] = stock + count
                    record.traded = (record.traded or 0) + count
                    record.coins = (record.coins or 0) + revenue
                    record.item_cursor = index % spec_count + 1
                    return
                else
                    inventory.insert{
                        name = spec.name,
                        count = count,
                        quality = 'normal',
                    }
                end
            elseif removed > 0 then
                inventory.insert{
                    name = spec.name,
                    count = removed,
                    quality = 'normal',
                }
            end
        end
    end
end

local function process_some_boxes()
    local order = storage.market_trade_order
    if #order == 0 then return end
    local count = math.min(config.market_boxes_per_pass, #order)
    local cursor = math.min(storage.market_trade_cursor or 1, #order)
    for _ = 1, count do
        if #order == 0 then break end
        if cursor > #order then cursor = 1 end
        local unit_number = order[cursor]
        local record = storage.market_trade_boxes[unit_number]
        local entity, owner = record and validate_record(unit_number, record)
        if entity then
            if record.mode == 'buy' then
                process_buy_box(entity, owner, record)
            else
                process_sell_box(entity, owner, record)
            end
            cursor = cursor + 1
        else
            order = storage.market_trade_order
            if cursor > #order then cursor = 1 end
        end
    end
    storage.market_trade_cursor = cursor
end

local function close_relative_gui(player)
    if not (player and player.valid) then return end
    local frame = player.gui.relative[FRAME_NAME]
    if frame and frame.valid then frame.destroy() end
end

local function format_integer(value)
    local text = tostring(math.floor(value or 0))
    local changed
    repeat
        text, changed = text:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    until changed == 0
    return text
end

local function render_relative_gui(player, entity)
    close_relative_gui(player)
    local mode = box_mode(entity)
    if not mode then return end
    local frame = player.gui.relative.add{
        type = 'frame',
        name = FRAME_NAME,
        direction = 'vertical',
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            position = defines.relative_gui_position.right,
        },
    }
    frame.add{
        type = 'label',
        caption = mode == 'buy' and {'un.market-auto-buy-title'}
            or {'un.market-auto-sell-title'},
        style = 'frame_title',
    }
    local description = frame.add{
        type = 'label',
        caption = mode == 'buy' and {'un.market-auto-buy-help'}
            or {'un.market-auto-sell-help'},
    }
    description.style.single_line = false
    description.style.maximal_width = 360
    local record = storage.market_trade_boxes[entity.unit_number]
    local owner = record and game.get_player(record.owner_index)
    if record and owner and owner.index ~= player.index then
        frame.add{
            type = 'label',
            caption = {'un.market-owned-by', owner.name},
        }
    else
        frame.add{
            type = 'label',
            caption = mode == 'buy' and {'un.market-max-price'}
                or {'un.market-min-price'},
        }
        frame.add{
            type = 'textfield',
            name = PRICE_FIELD_NAME,
            text = tostring(record and record.price_limit or (mode == 'buy' and 100 or 1)),
            numeric = true,
            allow_decimal = true,
            allow_negative = false,
        }
        local buttons = frame.add{type = 'flow', direction = 'horizontal'}
        buttons.add{
            type = 'button',
            name = SAVE_BUTTON_NAME,
            caption = record and {'un.market-update'} or {'un.market-enable'},
            tags = {unit_number = entity.unit_number},
        }
        if record then
            buttons.add{
                type = 'button',
                name = REMOVE_BUTTON_NAME,
                caption = {'un.market-disable'},
                tags = {unit_number = entity.unit_number},
            }
            frame.add{
                type = 'label',
                caption = mode == 'buy' and {
                    'un.market-box-bought',
                    format_integer(record.traded),
                    format_integer(record.coins),
                } or {
                    'un.market-box-sold',
                    format_integer(record.traded),
                    format_integer(record.coins),
                },
            }
        end
    end
    frame.add{type = 'line'}
    frame.add{type = 'label', caption = {'un.market-local-prices'}}
    local market = market_for_force(entity.force.name)
    local list = frame.add{type = 'table', column_count = 3}
    list.add{type = 'label', caption = {'un.market-column-item'}}
    list.add{type = 'label', caption = {'un.market-column-stock'}}
    list.add{type = 'label', caption = {'un.market-column-price'}}
    for _, spec in ipairs(config.market_items or {}) do
        list.add{
            type = 'label',
            caption = {'', '[img=item/' .. spec.name .. '] ',
                {'item-name.' .. spec.name}},
        }
        list.add{type = 'label', caption = format_integer(market[spec.name])}
        list.add{
            type = 'label',
            caption = string.format('%.2f', spot_price(spec, market[spec.name])),
        }
    end
end

local function on_gui_opened(event)
    local player = game.get_player(event.player_index)
    if player then close_relative_gui(player) end
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not (player and entity and box_mode(entity)) then return end
    render_relative_gui(player, entity)
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid
            and (element.name == SAVE_BUTTON_NAME
                or element.name == REMOVE_BUTTON_NAME)) then
        return
    end
    local player = game.get_player(event.player_index)
    local unit_number = tonumber(element.tags.unit_number)
    local entity = unit_number and game.get_entity_by_unit_number(unit_number)
    local mode = box_mode(entity)
    if not (player and entity and mode and player.force == entity.force
            and factions.planet_of_force(entity.force)
            and surfaces.context_planet(entity.surface)
                == factions.planet_of_force(entity.force)) then
        if player then player.print({'un.market-invalid-box'}) end
        return
    end
    local record = storage.market_trade_boxes[unit_number]
    if record and record.owner_index ~= player.index then
        player.print({'un.market-not-owner'})
        return
    end
    if element.name == REMOVE_BUTTON_NAME then
        unregister(unit_number)
        player.print({'un.market-disabled'})
        render_relative_gui(player, entity)
        return
    end
    local frame = player.gui.relative[FRAME_NAME]
    local field = frame and frame.valid and frame[PRICE_FIELD_NAME]
    local price_limit = field and tonumber(field.text)
    if not valid_number(price_limit) or price_limit <= 0
            or price_limit > 1000000000 then
        player.print({'un.market-invalid-price'})
        return
    end
    storage.market_trade_boxes[unit_number] = {
        owner_index = player.index,
        force_name = entity.force.name,
        mode = mode,
        price_limit = price_limit,
        traded = record and record.traded or 0,
        coins = record and record.coins or 0,
        item_cursor = record and record.item_cursor or 1,
    }
    rebuild_order()
    player.print({'un.market-enabled'})
    render_relative_gui(player, entity)
end

local function forget_entity(event)
    local entity = event.entity
    local unit_number = entity and entity.unit_number
    if unit_number then unregister(unit_number) end
end

events.on(defines.events.on_gui_opened, on_gui_opened)
events.on(defines.events.on_gui_click, on_gui_click)
events.on(defines.events.on_player_mined_entity, forget_entity)
events.on(defines.events.on_robot_mined_entity, forget_entity)
events.on(defines.events.on_entity_died, forget_entity)
events.on(defines.events.on_player_removed, function(event)
    local changed = false
    for unit_number, record in pairs(storage.market_trade_boxes) do
        if record.owner_index == event.player_index then
            storage.market_trade_boxes[unit_number] = nil
            changed = true
        end
    end
    if changed then rebuild_order() end
end)

scheduler.every(config.market_process_ticks, process_some_boxes)

return M
