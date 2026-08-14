local config = require('config')
local economy = require('scripts.economy')
local factions = require('scripts.factions')
local market = require('scripts.market')

local M = {}

local CONTROLS_NAME = 'un_market_controls'
local AMOUNT_NAME = 'un_market_amount'
local BUY_BUTTON_PREFIX = 'un_market_buy_'
local SCROLL_NAME = 'un_market_scroll'
local LIST_NAME = 'un_market_list'
local BUY_BUTTON_WIDTH = 190

local function format_integer(value)
    local raw = string.format('%.0f', value)
    local sign, digits = raw:match('^([%-]?)(%d+)$')
    if not digits then return raw end
    local reversed = digits:reverse():gsub('(%d%d%d)', '%1,')
    return sign .. reversed:reverse():gsub('^,', '')
end

function M.error_caption(err)
    return {'un.market-error-' .. tostring(err)}
end

function M.amount(content)
    local controls = content and content.valid and content[CONTROLS_NAME]
    local field = controls and controls.valid and controls[AMOUNT_NAME]
    local amount = field and field.valid and tonumber(field.text)
    if not amount or amount < 1 or amount ~= math.floor(amount) then return nil end
    return amount
end

function M.render(player, frame, content, selected_amount, selected_group)
    selected_amount = math.max(1, math.floor(tonumber(selected_amount) or 1))
    selected_group = selected_group or frame.tags.market_group or 'raw'
    local planet_name = factions.of_player(player)
    local market_cash = market.cash(player) or 0
    local heading = content.add{type = 'flow', direction = 'horizontal'}
    heading.style.vertical_align = 'center'
    heading.add{
        type = 'label',
        caption = {
            'un.market-heading',
            factions.display_name(planet_name),
            format_integer(economy.get_balance(player.index)),
            format_integer(market_cash),
        },
    }
    local info = heading.add{
        type = 'sprite',
        sprite = 'info',
        tooltip = {'un.market-tooltip'},
    }
    info.style.width = 20
    info.style.height = 20

    local controls = content.add{
        type = 'flow',
        name = CONTROLS_NAME,
        direction = 'horizontal',
    }
    controls.style.vertical_align = 'center'
    controls.add{type = 'label', caption = {'un.market-buy-amount'}}
    local amount = controls.add{
        type = 'textfield',
        name = AMOUNT_NAME,
        text = tostring(selected_amount),
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
    }
    amount.style.width = 100
    controls.add{
        type = 'button',
        caption = {'un.market-sell-all'},
        tooltip = {'un.market-sell-all-tooltip'},
        tags = {action = 'market-sell-all'},
    }

    local groups = content.add{type = 'flow', direction = 'horizontal'}
    for _, group in ipairs{'raw', 'material', 'component', 'science'} do
        groups.add{
            type = 'button',
            caption = {'un.market-group-' .. group},
            enabled = selected_group ~= group,
            tags = {action = 'market-set-group', group = group},
        }
    end

    local items, err = market.list(player)
    if not items then
        content.add{type = 'label', caption = M.error_caption(err)}
    else
        local scroll = content.add{type = 'scroll-pane', name = SCROLL_NAME}
        scroll.style.maximal_height = 520
        scroll.style.horizontally_stretchable = true
        local list = scroll.add{
            type = 'table',
            name = LIST_NAME,
            column_count = 6,
            style = 'bordered_table',
        }
        list.add{type = 'label', caption = {'un.market-column-item'}}
        list.add{type = 'label', caption = {'un.market-column-carried'}}
        list.add{type = 'label', caption = {'un.market-column-stock'}}
        list.add{type = 'label', caption = {'un.market-column-price'}}
        list.add{type = 'label', caption = {'un.market-column-sell'}}
        list.add{type = 'label', caption = {'un.market-column-buy'}}
        for _, item in ipairs(items) do
            if item.group == selected_group then
                list.add{
                    type = 'label',
                    caption = {'', '[img=item/' .. item.name .. '] ',
                        prototypes.item[item.name]
                            and prototypes.item[item.name].localised_name
                            or item.name},
                }
                list.add{type = 'label', caption = format_integer(item.carried)}
                list.add{type = 'label', caption = format_integer(item.stock)}
                list.add{
                    type = 'label',
                    caption = {
                        'un.market-price',
                        format_integer(math.ceil(item.price)),
                    },
                }
                local sell = list.add{
                    type = 'button',
                    caption = {'un.market-sell-item-all'},
                    tooltip = {'un.market-sell-item-tooltip'},
                    tags = {action = 'market-sell-item', item_name = item.name},
                }
                sell.enabled = item.carried > 0
                local quote, quote_error = market.buy_quote(
                    player, item.name, selected_amount
                )
                local buy = list.add{
                    type = 'button',
                    name = BUY_BUTTON_PREFIX .. item.name,
                    caption = quote and {
                        'un.market-buy-item-quote', format_integer(quote),
                    } or {'un.market-buy-item'},
                    tooltip = quote and {
                        'un.market-buy-item-tooltip',
                        format_integer(selected_amount),
                        format_integer(quote),
                    } or M.error_caption(quote_error),
                    tags = {action = 'market-buy-item', item_name = item.name},
                }
                buy.style.width = BUY_BUTTON_WIDTH
                buy.enabled = quote ~= nil
            end
        end
    end
    local tags = frame.tags
    tags.page = 'market'
    tags.property_revision = -1
    tags.list_refresh_market = math.floor(
        game.tick / config.gui_list_refresh_ticks
    )
    tags.market_revision = market.revision(player)
    tags.market_group = selected_group
    frame.tags = tags
end

local function refresh_quotes(player, content, amount)
    local scroll = content and content.valid and content[SCROLL_NAME]
    local list = scroll and scroll.valid and scroll[LIST_NAME]
    if not (list and list.valid) then return false end
    for _, item in ipairs(market.list(player) or {}) do
        local button = list[BUY_BUTTON_PREFIX .. item.name]
        if button and button.valid then
            local quote, err = market.buy_quote(player, item.name, amount)
            button.caption = quote and {
                'un.market-buy-item-quote', format_integer(quote),
            } or {'un.market-buy-item'}
            button.tooltip = quote and {
                'un.market-buy-item-tooltip',
                format_integer(amount),
                format_integer(quote),
            } or M.error_caption(err)
            button.enabled = quote ~= nil
        end
    end
    return true
end

function M.handle_click(player, element, frame, content)
    local tags = element.tags
    if tags.action == 'market-set-group' then
        local amount = M.amount(content) or 1
        content.clear()
        M.render(player, frame, content, amount, tags.group)
        return true
    end
    if tags.action ~= 'market-buy-item'
            and tags.action ~= 'market-sell-item'
            and tags.action ~= 'market-sell-all'
            and tags.action ~= 'market-confirm-sell-all' then
        return false
    end
    local amount = M.amount(content) or 1
    if tags.action == 'market-buy-item' then
        if not M.amount(content) then
            player.print({'un.market-error-invalid-count'})
            return true
        end
        local ok, count, cost = market.buy(player, tags.item_name, amount)
        player.print(ok and {
            'un.market-bought',
            '[img=item/' .. tags.item_name .. ']',
            format_integer(count),
            format_integer(cost),
        } or M.error_caption(count))
    elseif tags.action == 'market-sell-item' then
        local ok, count, revenue = market.sell(player, tags.item_name)
        player.print(ok and {
            'un.market-sold',
            '[img=item/' .. tags.item_name .. ']',
            format_integer(count),
            format_integer(revenue),
        } or M.error_caption(count))
    elseif tags.action == 'market-sell-all' then
        local ok, count, revenue = market.sell_all_quote(player)
        if not ok then
            player.print(M.error_caption(count))
            return true
        end
        element.caption = {
            'un.market-sell-all-confirm',
            format_integer(count),
            format_integer(revenue),
        }
        element.tooltip = {'un.market-sell-all-confirm-tooltip'}
        element.tags = {
            action = 'market-confirm-sell-all',
            quoted_count = count,
            quoted_revenue = revenue,
        }
        return true
    else
        local ok, count, revenue = market.sell_all(
            player, tags.quoted_count, tags.quoted_revenue
        )
        player.print(ok and {
            'un.market-sold-all',
            format_integer(count),
            format_integer(revenue),
        } or M.error_caption(count))
    end
    if frame and frame.valid then
        content.clear()
        M.render(player, frame, content, amount)
    end
    return true
end


function M.handle_text_changed(player, element, frame, content)
    if not (element and element.valid and element.name == AMOUNT_NAME) then
        return false
    end
    local amount = tonumber(element.text)
    if not amount or amount < 1 or amount ~= math.floor(amount) then
        return true
    end
    refresh_quotes(player, content, amount)
    return true
end

return M
