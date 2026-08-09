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
local BALANCE_NAME = 'un_overview_balance'
local UBI_PROGRESS_NAME = 'un_overview_ubi_progress'
local UBI_CLAIM_NAME = 'un_overview_ubi_claim'
local SURFACE_NAME = 'un_overview_surface'
local DROPOFF_NAME = 'un_overview_dropoff'
local TABLE_NAME = 'un_overview_table'
local TRAVEL_NAME = 'un_overview_travel'
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

local function render_property_table(player, frame)
    local old = frame[PROPERTY_TABLE_NAME]
    if old and old.valid then old.destroy() end
    local list = frame.add{
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
    frame.tags = {property_revision = storage.property_revision or 0}
end

local function property_error(err)
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'renew-limit' then return {'un.property-error-renew-limit'} end
    if err == 'price-increased' then return {'un.property-error-price-changed'} end
    if err == 'not-owner' or err == 'already-owner' then
        return {'un.property-error-ownership'}
    end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    return {'un.property-error-unavailable'}
end

local function update_frame(player)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then
        open_players[player.index] = nil
        return
    end

    local table_element = frame[TABLE_NAME]
    if not (table_element and table_element.valid) then return end

    local balance = table_element[BALANCE_NAME]
    if balance and balance.valid then
        balance.caption = format_integer(economy.get_balance(player.index))
    end

    local claimable = economy.get_claimable_ubi(player.index)
    local capacity = economy.get_ubi_capacity()

    local surface_label = table_element[SURFACE_NAME]
    if surface_label and surface_label.valid then
        local surface = player.physical_surface
        surface_label.caption = surface and surface.valid
            and surface.localised_name or {'un.unknown'}
    end

    local dropoff = table_element[DROPOFF_NAME]
    if dropoff and dropoff.valid then
        dropoff.caption = linked_inventory.has_active_dropoff(player.index)
            and {'un.dropoff-active'} or {'un.dropoff-missing'}
    end

    local progress = frame[UBI_PROGRESS_NAME]
    if progress and progress.valid then
        progress.value = capacity > 0 and claimable / capacity or 0
        progress.caption = ''
    end

    local claim = frame[UBI_CLAIM_NAME]
    if claim and claim.valid then
        claim.enabled = claimable > 0
        claim.caption = {
            'un.ubi-claim',
            format_integer(claimable),
            format_integer(capacity),
        }
    end

    local travel = frame[TRAVEL_NAME]
    if travel and travel.valid then
        travel.caption = player.physical_surface.name == config.hospice_surface_name
            and {'un.travel-nauvis'} or {'un.travel-hospice'}
    end

    if (frame.tags.property_revision or -1) ~= (storage.property_revision or 0) then
        render_property_table(player, frame)
    else
        local property_table = frame[PROPERTY_TABLE_NAME]
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

    frame.add{
        type = 'label',
        caption = {'un.overview-title'},
        style = 'heading_2_label',
    }
    local table_element = frame.add{
        type = 'table',
        name = TABLE_NAME,
        column_count = 2,
    }
    table_element.add{type = 'label', caption = {'un.credit-label'}}
    table_element.add{type = 'label', name = BALANCE_NAME}
    table_element.add{type = 'label', caption = {'un.surface-label'}}
    table_element.add{type = 'label', name = SURFACE_NAME}
    table_element.add{type = 'label', caption = {'un.dropoff-label'}}
    table_element.add{type = 'label', name = DROPOFF_NAME}

    local progress = frame.add{
        type = 'progressbar',
        name = UBI_PROGRESS_NAME,
        value = 0,
    }
    progress.style.horizontally_stretchable = true
    local claim = frame.add{
        type = 'button',
        name = UBI_CLAIM_NAME,
        caption = {'un.ubi-claim', 0, economy.get_ubi_capacity()},
    }
    claim.style.horizontally_stretchable = true

    local travel = frame.add{
        type = 'button',
        name = TRAVEL_NAME,
        caption = {'un.travel-hospice'},
    }
    travel.style.horizontally_stretchable = true
    frame.add{
        type = 'label',
        caption = {'un.property-title'},
        style = 'heading_2_label',
    }
    render_property_table(player, frame)

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
        -- Rebuild an open Stage 1 window so old saves cannot retain the removed
        -- automatic-UBI controls after a configuration change.
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
    elseif element.name == UBI_CLAIM_NAME then
        economy.claim_ubi(player.index)
        update_frame(player)
    elseif element.name == TRAVEL_NAME then
        local ok, err
        if player.physical_surface.name == config.hospice_surface_name then
            ok, err = surfaces.to_nauvis(player)
        else
            ok, err = surfaces.to_hospice(player)
        end
        if ok then close_frame(player) else player.print(property_error(err)) end
    else
        local tags = element.tags
        if tags.action == 'property-buy' then
            local property = properties.get(tags.property_id)
            if not property then
                player.print({'un.property-missing'})
                render_property_table(player, player.gui.screen[FRAME_NAME])
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
            render_property_table(player, player.gui.screen[FRAME_NAME])
            update_frame(player)
        elseif tags.action == 'property-renew' then
            local ok, err = properties.renew(player, tags.property_id)
            if not ok then player.print(property_error(err)) end
            render_property_table(player, player.gui.screen[FRAME_NAME])
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
