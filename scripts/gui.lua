local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')
local properties = require('scripts.properties')
local scheduler = require('scripts.scheduler')
local surfaces = require('scripts.surfaces')

local M = {}

local BUTTON_NAME = 'un_main_button'
local FRAME_NAME = 'un_main_frame'
local CLOSE_NAME = 'un_main_close'
local CONTENT_NAME = 'un_main_content'
local NAVIGATION_NAME = 'un_main_navigation'
local NAV_UBI_NAME = 'un_nav_ubi'
local NAV_TRAVEL_NAME = 'un_nav_travel'
local NAV_PROPERTY_NAME = 'un_nav_property'
local BALANCE_TABLE_NAME = 'un_ubi_balance_table'
local BALANCE_NAME = 'un_ubi_balance'
local UBI_PROGRESS_NAME = 'un_ubi_progress'
local UBI_CLAIM_NAME = 'un_ubi_claim'
local LOCATION_TABLE_NAME = 'un_dropoff_location_table'
local DROPOFF_LOCATION_NAME = 'un_dropoff_location'
local TRAVEL_PLANET_NAME = 'un_travel_planet'
local TRAVEL_HOSPICE_NAME = 'un_travel_hospice'
local PROPERTY_TABLE_NAME = 'un_property_table'

-- GUI-only state. UBI itself never depends on this table and is calculated from
-- game.tick only when queried or claimed.
local open_players = {}

local function format_integer(value)
    local raw = string.format('%.0f', value)
    local sign, digits = raw:match('^([%-]?)(%d+)$')
    if not digits then return raw end
    local reversed = digits:reverse():gsub('(%d%d%d)', '%1,')
    local grouped = reversed:reverse():gsub('^,', '')
    return sign .. grouped
end

local function format_coordinate(value)
    return string.format('%.1f', value)
end

function M.ensure_button(player)
    local root = player.gui.top
    local button = root[BUTTON_NAME]
    -- Migrate the old caption button in existing saves.
    if button and button.valid and button.type ~= 'sprite-button' then
        button.destroy()
        button = nil
    end
    if not (button and button.valid) then
        button = root.add{
            type = 'sprite-button',
            name = BUTTON_NAME,
            sprite = 'item/coin',
            tooltip = {'un.main-button-tooltip'},
        }
    end
    return button
end

local function property_price_name(property_id)
    return 'un_property_price_' .. tostring(property_id)
end

local function set_frame_state(frame, page, property_revision)
    frame.tags = {
        page = page,
        property_revision = property_revision or -1,
    }
end

local function render_property_table(player, frame, content)
    local old = content[PROPERTY_TABLE_NAME]
    if old and old.valid then old.destroy() end
    local list = content.add{
        type = 'table',
        name = PROPERTY_TABLE_NAME,
        column_count = 5,
    }
    list.add{type = 'label', caption = {'un.property-column-name'}}
    list.add{type = 'label', caption = {'un.property-column-owner'}}
    list.add{type = 'label', caption = {'un.property-column-price'}}
    list.add{type = 'label', caption = ''}
    list.add{type = 'label', caption = ''}

    for _, property in ipairs(properties.list()) do
        list.add{type = 'label', caption = properties.display_name(property)}
        local owner = properties.owner_name(property)
        list.add{
            type = 'label',
            caption = owner or {'un.property-vacant'},
        }
        list.add{
            type = 'label',
            name = property_price_name(property.id),
            caption = format_integer(properties.current_price(property)),
        }
        if property.owner_index == player.index then
            list.add{
                type = 'button',
                caption = {'un.property-enter'},
                tags = {action = 'property-enter', property_id = property.id},
            }
            list.add{
                type = 'button',
                caption = {
                    'un.property-renew',
                    format_integer(properties.renew_fee(property)),
                },
                tags = {action = 'property-renew', property_id = property.id},
            }
        else
            list.add{
                type = 'button',
                caption = {'un.property-buy'},
                tags = {action = 'property-buy', property_id = property.id},
            }
            list.add{type = 'label', caption = ''}
        end
    end
    set_frame_state(frame, 'property', storage.property_revision or 0)
end

local function render_ubi_page(frame, content)
    local balance = content.add{
        type = 'table',
        name = BALANCE_TABLE_NAME,
        column_count = 2,
    }
    balance.add{type = 'label', caption = {'un.credit-label'}}
    balance.add{type = 'label', name = BALANCE_NAME}

    local progress = content.add{
        type = 'progressbar',
        name = UBI_PROGRESS_NAME,
        value = 0,
    }
    progress.style.horizontally_stretchable = true
    local claim = content.add{
        type = 'button',
        name = UBI_CLAIM_NAME,
        caption = {'un.ubi-claim', 0, economy.get_ubi_capacity()},
    }
    claim.style.horizontally_stretchable = true
    set_frame_state(frame, 'ubi')
end

local function render_travel_page(frame, content)
    local location = content.add{
        type = 'table',
        name = LOCATION_TABLE_NAME,
        column_count = 2,
    }
    location.add{type = 'label', caption = {'un.dropoff-location-label'}}
    location.add{type = 'label', name = DROPOFF_LOCATION_NAME}

    local planet = content.add{
        type = 'button',
        name = TRAVEL_PLANET_NAME,
        caption = {'un.travel-planet'},
    }
    planet.style.horizontally_stretchable = true
    local hospice = content.add{
        type = 'button',
        name = TRAVEL_HOSPICE_NAME,
        caption = {'un.travel-hospice'},
    }
    hospice.style.horizontally_stretchable = true
    set_frame_state(frame, 'travel')
end

local function render_page(player, page)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then return end
    local content = frame[CONTENT_NAME]
    if not (content and content.valid) then return end
    content.clear()

    if page == 'travel' then
        render_travel_page(frame, content)
    elseif page == 'property' then
        render_property_table(player, frame, content)
    else
        page = 'ubi'
        render_ubi_page(frame, content)
    end

    local navigation = frame[NAVIGATION_NAME]
    navigation[NAV_UBI_NAME].enabled = page ~= 'ubi'
    navigation[NAV_TRAVEL_NAME].enabled = page ~= 'travel'
    navigation[NAV_PROPERTY_NAME].enabled = page ~= 'property'
end

local function property_error(err)
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'renew-limit' then return {'un.property-error-renew-limit'} end
    if err == 'price-increased' then return {'un.property-error-price-changed'} end
    if err == 'not-owner' or err == 'already-owner' then
        return {'un.property-error-ownership'}
    end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'position-missing' then return {'un.travel-no-position'} end
    return {'un.property-error-unavailable'}
end

local function update_frame(player)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then
        open_players[player.index] = nil
        return
    end
    local content = frame[CONTENT_NAME]
    if not (content and content.valid) then return end
    local page = frame.tags.page or 'ubi'

    if page == 'ubi' then
        local balance_table = content[BALANCE_TABLE_NAME]
        local balance = balance_table and balance_table.valid
            and balance_table[BALANCE_NAME]
        if balance and balance.valid then
            balance.caption = format_integer(economy.get_balance(player.index))
        end

        local claimable = economy.get_claimable_ubi(player.index)
        local capacity = economy.get_ubi_capacity()
        local progress = content[UBI_PROGRESS_NAME]
        if progress and progress.valid then
            progress.value = capacity > 0 and claimable / capacity or 0
            progress.caption = ''
        end
        local claim = content[UBI_CLAIM_NAME]
        if claim and claim.valid then
            claim.enabled = claimable > 0
            claim.caption = {
                'un.ubi-claim',
                format_integer(claimable),
                format_integer(capacity),
            }
        end
    elseif page == 'travel' then
        local location_table = content[LOCATION_TABLE_NAME]
        local location = location_table and location_table.valid
            and location_table[DROPOFF_LOCATION_NAME]
        if location and location.valid then
            local dropoff = linked_inventory.get_active_dropoff(player.index)
            if dropoff then
                location.caption = {
                    'un.dropoff-location',
                    dropoff.surface.localised_name,
                    format_coordinate(dropoff.position.x),
                    format_coordinate(dropoff.position.y),
                }
            else
                location.caption = {'un.dropoff-missing'}
            end
        end
    elseif page == 'property' then
        if (frame.tags.property_revision or -1) ~= (storage.property_revision or 0) then
            render_property_table(player, frame, content)
        else
            local property_table = content[PROPERTY_TABLE_NAME]
            if property_table and property_table.valid then
                for _, property in ipairs(properties.list()) do
                    local price = property_table[property_price_name(property.id)]
                    if price and price.valid then
                        price.caption = format_integer(properties.current_price(property))
                    end
                end
            end
        end
    end
end

local function close_frame(player)
    open_players[player.index] = nil
    local frame = player.gui.screen[FRAME_NAME]
    if frame and frame.valid then frame.destroy() end
end

local function open_frame(player)
    close_frame(player)
    local frame = player.gui.screen.add{
        type = 'frame',
        name = FRAME_NAME,
        direction = 'vertical',
    }

    local title = frame.add{type = 'flow', direction = 'horizontal'}
    title.drag_target = frame
    local heading = title.add{
        type = 'label',
        caption = {'un.window-title'},
        style = 'frame_title',
    }
    heading.drag_target = frame
    local spacer = title.add{type = 'empty-widget', style = 'draggable_space_header'}
    spacer.style.horizontally_stretchable = true
    spacer.style.height = 24
    title.add{
        type = 'sprite-button',
        name = CLOSE_NAME,
        sprite = 'utility/close',
        style = 'frame_action_button',
        tooltip = {'un.close'},
    }

    local navigation = frame.add{
        type = 'flow',
        name = NAVIGATION_NAME,
        direction = 'horizontal',
    }
    navigation.add{type = 'button', name = NAV_UBI_NAME, caption = {'un.page-ubi'}}
    navigation.add{type = 'button', name = NAV_TRAVEL_NAME, caption = {'un.page-travel'}}
    navigation.add{type = 'button', name = NAV_PROPERTY_NAME, caption = {'un.page-property'}}

    local content = frame.add{
        type = 'flow',
        name = CONTENT_NAME,
        direction = 'vertical',
    }
    content.style.horizontally_stretchable = true

    render_page(player, 'ubi')
    frame.force_auto_center()
    player.opened = frame
    open_players[player.index] = true
    update_frame(player)
end

local function ensure_player(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    economy.ensure_account(player.index)
    M.ensure_button(player)
end

function M.ensure_all()
    for _, player in pairs(game.players) do
        economy.ensure_account(player.index)
        M.ensure_button(player)
        -- Rebuild open windows when the scenario GUI structure changes.
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then
            close_frame(player)
            if player.connected then open_frame(player) end
        end
    end
end

events.on(defines.events.on_player_created, ensure_player)
events.on(defines.events.on_player_joined_game, ensure_player)
events.on(defines.events.on_player_left_game, function(event)
    open_players[event.player_index] = nil
end)

events.on(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if element.name == BUTTON_NAME then
        M.ensure_button(player)
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then close_frame(player) else open_frame(player) end
    elseif element.name == CLOSE_NAME then
        close_frame(player)
    elseif element.name == NAV_UBI_NAME then
        render_page(player, 'ubi')
        update_frame(player)
    elseif element.name == NAV_TRAVEL_NAME then
        render_page(player, 'travel')
        update_frame(player)
    elseif element.name == NAV_PROPERTY_NAME then
        render_page(player, 'property')
        update_frame(player)
    elseif element.name == UBI_CLAIM_NAME then
        economy.claim_ubi(player.index)
        update_frame(player)
    elseif element.name == TRAVEL_PLANET_NAME then
        local ok, err = surfaces.to_planet(player)
        if ok then close_frame(player) else player.print(property_error(err)) end
    elseif element.name == TRAVEL_HOSPICE_NAME then
        local ok, err = surfaces.to_hospice(player)
        if ok then close_frame(player) else player.print(property_error(err)) end
    else
        local tags = element.tags
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if not (content and content.valid) then return end
        if tags.action == 'property-buy' then
            local property = properties.get(tags.property_id)
            if not property then
                player.print({'un.property-missing'})
                render_property_table(player, frame, content)
                return
            end
            local quote = properties.current_price(property)
            element.caption = {'un.property-confirm-buy', format_integer(quote)}
            element.tags = {
                action = 'property-confirm-buy',
                property_id = property.id,
                quoted_price = quote,
            }
        elseif tags.action == 'property-confirm-buy' then
            local ok, err = properties.buy(player, tags.property_id, tags.quoted_price)
            if not ok then player.print(property_error(err)) end
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action == 'property-renew' then
            local ok, err = properties.renew(player, tags.property_id)
            if not ok then player.print(property_error(err)) end
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action == 'property-enter' then
            local ok, err = properties.enter(player, tags.property_id)
            if ok then close_frame(player)
            else player.print(property_error(err)) end
        end
    end
end)

events.on(defines.events.on_gui_closed, function(event)
    local element = event.element
    if not (element and element.valid and element.name == FRAME_NAME) then return end
    local player = game.get_player(event.player_index)
    if player then close_frame(player) end
end)

economy.on_balance_changed(function(player_index)
    if not open_players[player_index] then return end
    local player = game.get_player(player_index)
    if player and player.valid then update_frame(player) end
end)

-- This refreshes presentation only for currently open windows. It never grants
-- credit and never traverses offline or unrelated players.
scheduler.every(config.gui_refresh_ticks, function()
    for player_index in pairs(open_players) do
        local player = game.get_player(player_index)
        if player and player.valid and player.connected then
            update_frame(player)
        else
            open_players[player_index] = nil
        end
    end
end)

return M
