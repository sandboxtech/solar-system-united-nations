local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local experience = require('scripts.experience')
local properties = require('scripts.properties')
local scheduler = require('scripts.scheduler')
local ships = require('scripts.ships')
local social = require('scripts.social')
local surfaces = require('scripts.surfaces')

local M = {}

local HUD_FLOW_NAME = 'un_hud_flow'
local HUD_LAYOUT_VERSION = 7
local HUD_TITLE_NAME = 'un_hud_title'
local LEGACY_BUTTON_NAME = 'un_main_button'
local HUD_HELP_NAME = 'un_hud_help'
local HUD_UBI_NAME = 'un_hud_ubi'
local HUD_LAST_PROPERTY_NAME = 'un_hud_last_property'
local HUD_PROPERTY_NAME = 'un_hud_property'
local HUD_PLAYERS_NAME = 'un_hud_players'
local FRAME_NAME = 'un_main_frame'
local CLOSE_NAME = 'un_main_close'
local CONTENT_NAME = 'un_main_content'
local NAVIGATION_NAME = 'un_main_navigation'
local NAV_HELP_NAME = 'un_nav_help'
local NAV_UBI_NAME = 'un_nav_ubi'
local NAV_PROPERTY_NAME = 'un_nav_property'
local NAV_PLAYERS_NAME = 'un_nav_players'
local HELP_BRIEF_NAME = 'un_help_brief'
local HELP_ADVANCED_NAME = 'un_help_advanced'
local HELP_FULL_NAME = 'un_help_full'
local HELP_DETAILS_NAME = 'un_help_details'
local PROPERTY_ACCESS_NAME = 'un_property_access'
local PROPERTY_ACCESS_SECTION_NAME = 'un_property_access_section'
local BALANCE_TABLE_NAME = 'un_ubi_balance_table'
local BALANCE_NAME = 'un_ubi_balance'
local UBI_PROGRESS_NAME = 'un_ubi_progress'
local UBI_CLAIM_NAME = 'un_ubi_claim'
local TRAVEL_PLANET_NAME = 'un_travel_planet'
local TRAVEL_HOSPICE_NAME = 'un_travel_hospice'
local SUICIDE_NAME = 'un_suicide'
local SHIP_STATUS_NAME = 'un_ship_status'
local SHIP_ACTIONS_NAME = 'un_ship_actions'
local SHIP_CREATE_NAME = 'un_ship_create'
local SHIP_SCUTTLE_NAME = 'un_ship_scuttle'
local PROPERTY_ACTIONS_NAME = 'un_property_actions'
local PROPERTY_TABLE_NAME = 'un_property_table'
local EXPERIENCE_SUMMARY_NAME = 'un_experience_summary'
local EXPERIENCE_TABLE_NAME = 'un_experience_table'
local PLAYER_ACTIONS_NAME = 'un_player_actions'
local PLAYER_TABLE_NAME = 'un_player_table'

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
    local old = root[LEGACY_BUTTON_NAME]
    if old and old.valid then old.destroy() end

    local hud = root[HUD_FLOW_NAME]
    if hud and hud.valid then
        local complete = hud.tags.layout_version == HUD_LAYOUT_VERSION
            and hud[HUD_TITLE_NAME]
            and hud[HUD_HELP_NAME]
            and hud[HUD_UBI_NAME]
            and hud[TRAVEL_PLANET_NAME]
            and hud[HUD_LAST_PROPERTY_NAME]
            and hud[HUD_PROPERTY_NAME]
            and hud[HUD_PLAYERS_NAME]
        if complete then return hud end
        hud.destroy()
    end
    hud = root.add{
        type = 'frame',
        name = HUD_FLOW_NAME,
        direction = 'horizontal',
    }
    hud.style.vertical_align = 'center'
    hud.style.padding = 4
    hud.tags = {layout_version = HUD_LAYOUT_VERSION}
    local title = hud.add{
        type = 'label',
        name = HUD_TITLE_NAME,
        caption = {'un.hud-title'},
    }
    title.style.font = 'default-bold'
    title.style.font_color = {r = 1, g = 1, b = 1}
    title.style.height = 40
    title.style.vertical_align = 'center'
    title.style.left_margin = 4
    title.style.right_margin = 10

    local buttons = {
        {HUD_HELP_NAME, 'virtual-signal/signal-info', {'un.hud-help-tooltip'}},
        {HUD_UBI_NAME, 'item/coin', {'un.hud-ubi-tooltip'}},
        {HUD_PROPERTY_NAME, 'item/stone-brick', {'un.hud-property-tooltip'}},
        {HUD_PLAYERS_NAME, 'entity/character', {'un.hud-players-tooltip'}},
        {TRAVEL_PLANET_NAME, 'space-location/nauvis', {'un.travel-planet'}},
        {HUD_LAST_PROPERTY_NAME, 'virtual-signal/signal-map-marker', {'un.hud-last-property-tooltip'}},
    }
    for _, spec in ipairs(buttons) do
        local button = hud.add{
            type = 'sprite-button',
            name = spec[1],
            sprite = spec[2],
            tooltip = spec[3],
        }
        button.style.width = 40
        button.style.height = 40
    end
    return hud
end

local function property_price_name(property_id)
    return 'un_property_price_' .. tostring(property_id)
end

local function property_buy_name(property_id)
    return 'un_property_buy_' .. tostring(property_id)
end

local function property_enter_name(property_id)
    return 'un_property_enter_' .. tostring(property_id)
end

local function disabled_tooltip(action, err)
    if err == 'surface-missing' or err == 'missing' then
        return {'un.property-error-unavailable'}
    end
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'travel-restricted' then return {'un.travel-restricted'} end
    if err == 'planet-closed' then return {'un.travel-planet-closed'} end
    if err == 'renew-limit' then return {'un.property-error-renew-limit'} end
    if action == 'buy' and err == 'already-owner' then
        return {'un.property-buy-disabled-owner'}
    end
    if action == 'enter' and err == 'not-owner' then
        return {'un.property-enter-disabled-private'}
    end
    if action == 'renew' and err == 'not-owner' then
        return {'un.property-renew-disabled-owner'}
    end
    return {'un.property-error-unavailable'}
end

local function experience_progress_name(index)
    return 'un_experience_progress_' .. tostring(index)
end

local function experience_amount_name(index)
    return 'un_experience_amount_' .. tostring(index)
end

local function set_frame_state(frame, page, property_revision)
    frame.tags = {
        page = page,
        property_revision = property_revision or -1,
    }
end

local function render_property_access_section(player, content)
    local flow = content.add{
        type = 'flow',
        name = PROPERTY_ACCESS_SECTION_NAME,
        direction = 'horizontal',
    }
    flow.style.vertical_align = 'center'
    flow.add{type = 'label', caption = {'un.property-access-label'}}
    flow.add{
        type = 'switch',
        name = PROPERTY_ACCESS_NAME,
        left_label_caption = {'un.property-access-private'},
        right_label_caption = {'un.property-access-public'},
        switch_state = properties.all_open(player.index) and 'right' or 'left',
        allow_none_state = false,
    }
end

local function render_property_table(player, frame, content)
    local old_actions = content[PROPERTY_ACTIONS_NAME]
    if old_actions and old_actions.valid then old_actions.destroy() end
    local old_access = content[PROPERTY_ACCESS_SECTION_NAME]
    if old_access and old_access.valid then old_access.destroy() end
    local old = content[PROPERTY_TABLE_NAME]
    if old and old.valid then old.destroy() end
    local property_list = properties.list()
    local actions = content.add{
        type = 'flow',
        name = PROPERTY_ACTIONS_NAME,
        direction = 'horizontal',
    }
    actions.add{
        type = 'button',
        name = TRAVEL_HOSPICE_NAME,
        caption = {'un.travel-hospice'},
    }
    local owned = 0
    for _, property in ipairs(property_list) do
        if property.owner_index == player.index then owned = owned + 1 end
    end
    if owned > 0 then render_property_access_section(player, content) end
    local list = content.add{
        type = 'table',
        name = PROPERTY_TABLE_NAME,
        column_count = 5,
    }
    list.add{type = 'label', caption = {'un.property-column-name'}}
    list.add{type = 'label', caption = {'un.property-column-owner'}}
    list.add{type = 'label', caption = {'un.property-column-price'}}
    list.add{type = 'label', caption = {'un.property-column-buy-renew'}}
    list.add{type = 'label', caption = {'un.property-enter'}}

    for _, property in ipairs(property_list) do
        list.add{
            type = 'label',
            caption = properties.display_name(property),
            tooltip = properties.feature_description(property),
        }
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
        local owns = property.owner_index == player.index
        local can_buy, buy_error
        if owns then
            can_buy, buy_error = properties.renew_availability(player, property)
        else
            can_buy, buy_error = properties.buy_availability(player, property)
        end
        list.add{
            type = 'button',
            name = property_buy_name(property.id),
            caption = owns and {
                'un.property-renew',
                format_integer(properties.renew_fee(property)),
            } or {'un.property-buy'},
            tooltip = can_buy and (owns and {'un.property-renew-tooltip'}
                or {'un.property-buy'})
                or disabled_tooltip(owns and 'renew' or 'buy', buy_error),
            enabled = can_buy,
            tags = {
                action = owns and 'property-renew' or 'property-buy',
                property_id = property.id,
            },
        }
        local can_enter, enter_error = properties.enter_availability(player, property)
        list.add{
            type = 'button',
            name = property_enter_name(property.id),
            caption = {'un.property-enter'},
            tooltip = can_enter and {'un.property-enter'}
                or disabled_tooltip('enter', enter_error),
            enabled = can_enter,
            tags = {action = 'property-enter', property_id = property.id},
        }
    end
    set_frame_state(frame, 'property', storage.property_revision or 0)
end

local function render_ubi_section(content)
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
end

local function render_ship_section(content)
    content.add{type = 'label', name = SHIP_STATUS_NAME}
    local ship_actions = content.add{
        type = 'flow',
        name = SHIP_ACTIONS_NAME,
        direction = 'horizontal',
    }
    ship_actions.add{
        type = 'button',
        name = SHIP_CREATE_NAME,
        caption = {'un.ship-create', format_integer(config.ship_credit_cost)},
    }
    ship_actions.add{
        type = 'button',
        name = SHIP_SCUTTLE_NAME,
        caption = {'un.ship-scuttle'},
    }
    local suicide = ship_actions.add{
        type = 'sprite-button',
        name = SUICIDE_NAME,
        sprite = 'utility/danger_icon',
        tooltip = {'un.suicide'},
    }
    suicide.style.width = 40
    suicide.style.height = 40
end

local function render_experience_section(content)
    content.add{type = 'label', caption = {'un.experience-help-1'}}
    content.add{type = 'label', caption = {'un.experience-help-2'}}
    content.add{type = 'label', caption = {'un.experience-help-3'}}
    local grid = content.add{
        type = 'table',
        name = EXPERIENCE_TABLE_NAME,
        column_count = 3,
    }
    for index, name in ipairs(config.science_pack_order) do
        grid.add{type = 'sprite', sprite = 'item/' .. name}
        local progress = grid.add{
            type = 'progressbar',
            name = experience_progress_name(index),
            value = 0,
        }
        progress.style.width = 120
        grid.add{type = 'label', name = experience_amount_name(index)}
    end
    content.add{type = 'label', name = EXPERIENCE_SUMMARY_NAME}
end

local function render_overview_page(player, frame, content)
    render_ubi_section(content)
    content.add{type = 'line'}
    render_ship_section(content)
    content.add{type = 'line'}
    render_experience_section(content)
    set_frame_state(frame, 'overview')
end

local function add_help_line(parent, caption, heading)
    local label = parent.add{type = 'label', caption = caption}
    label.style.single_line = false
    label.style.maximal_width = 720
    if heading then label.style.font = 'default-bold' end
    return label
end

local function render_help_page(frame, content, mode)
    mode = mode or 'brief'
    local title = content.add{
        type = 'label',
        caption = mode == 'full' and {'un.help-full-title'}
            or mode == 'advanced' and {'un.help-advanced-title'}
            or {'un.help-title'},
    }
    title.style.font = 'default-large-bold'
    local modes = content.add{type = 'flow', direction = 'horizontal'}
    local brief = modes.add{
        type = 'button',
        name = HELP_BRIEF_NAME,
        caption = {'un.help-mode-brief'},
    }
    local advanced = modes.add{
        type = 'button',
        name = HELP_ADVANCED_NAME,
        caption = {'un.help-mode-advanced'},
    }
    local full = modes.add{
        type = 'button',
        name = HELP_FULL_NAME,
        caption = {'un.help-mode-full'},
    }
    brief.enabled = mode ~= 'brief'
    advanced.enabled = mode ~= 'advanced'
    full.enabled = mode ~= 'full'

    if mode == 'brief' then
        add_help_line(content, {'un.help-step-linked-chest'})
        add_help_line(content, {'un.help-step-science'})
        add_help_line(content, {'un.help-step-property'})
        add_help_line(content, {'un.help-ubi'})
        set_frame_state(frame, 'help')
        return
    end

    local details = content.add{
        type = 'scroll-pane',
        name = HELP_DETAILS_NAME,
    }
    details.style.minimal_width = 740
    details.style.maximal_height = 620

    add_help_line(details, {'un.help-detail-economy-heading'}, true)
    add_help_line(details, {
        'un.help-detail-ubi',
        config.ubi_credit_per_second,
        config.ubi_max_seconds / 3600,
        economy.get_ubi_capacity(),
    })
    add_help_line(details, {'un.help-detail-linked-chest'})
    add_help_line(details, {
        'un.help-detail-science',
        config.science_conversion_ticks / config.ticks_per_minute,
        config.quality_credit_multiplier.normal,
        config.quality_credit_multiplier.uncommon,
        config.quality_credit_multiplier.rare,
        config.quality_credit_multiplier.epic,
        config.quality_credit_multiplier.legendary,
    })
    add_help_line(details, {'un.help-detail-experience'})

    add_help_line(details, {'un.help-detail-property-heading'}, true)
    add_help_line(details, {
        'un.help-detail-property-generation',
        config.property_initial_price_min,
        config.property_initial_price_max,
    })

    add_help_line(details, {'un.help-detail-cooperation-heading'}, true)
    add_help_line(details, {'un.help-detail-friends', config.friend_limit})
    add_help_line(details, {'un.help-detail-transfer'})

    add_help_line(details, {'un.help-detail-ship-heading'}, true)
    add_help_line(details, {
        'un.help-detail-ship',
        config.ship_credit_cost,
        config.ship_life_hours,
        config.ship_base_width,
        config.ship_width_per_level,
        config.ship_height,
    })
    add_help_line(details, {'un.help-detail-travel'})
    add_help_line(details, {'un.help-detail-resets'})

    if mode == 'full' then
        add_help_line(details, {'un.help-detail-formulas-heading'}, true)
        add_help_line(details, {
            'un.help-detail-property-price',
            config.property_decay_ticks / config.ticks_per_hour,
            config.property_price_cap,
        })
        add_help_line(details, {
            'un.help-detail-property-trade',
            config.property_default_tax * 100,
            config.property_decay_ticks / config.ticks_per_hour,
            config.property_max_future_ticks / config.ticks_per_hour,
        })
        add_help_line(details, {
            'un.help-detail-property-supply',
            config.property_supply_check_ticks / config.ticks_per_hour,
            config.property_supply_active_window_ticks / config.ticks_per_hour,
            config.property_supply_minimum,
            config.property_supply_per_active_player,
            config.property_supply_confirmation_checks,
            config.property_supply_change_chance * 100,
            config.property_supply_stale_ticks / config.ticks_per_hour,
            config.property_supply_low_vacancy * 100,
            config.property_supply_high_median_price,
            config.property_supply_high_vacancy * 100,
            config.property_supply_low_median_price,
        })
        add_help_line(details, {
            'un.help-detail-reset-schedule',
            config.public_planet_reset_hours.nauvis,
            config.public_planet_reset_hours.vulcanus,
            config.public_planet_reset_hours.gleba,
            config.public_planet_reset_hours.fulgora,
            config.public_planet_reset_hours.aquilo,
            config.player_cleanup_idle_hours,
        })
        add_help_line(details, {'un.help-detail-commands-heading'}, true)
        add_help_line(details, {'un.help-detail-command-friend'})
        add_help_line(details, {'un.help-detail-command-transfer'})
        add_help_line(details, {'un.help-detail-command-rename'})
        add_help_line(details, {'un.help-detail-command-admin'})
    end
    set_frame_state(frame, 'help')
end

local function player_signature()
    local parts = {}
    for _, player in pairs(game.players) do
        parts[#parts + 1] = tostring(player.index)
            .. (player.connected and '+' or '-')
    end
    table.sort(parts)
    return table.concat(parts, ',')
end

local function player_element_name(kind, player_index)
    return 'un_player_' .. kind .. '_' .. tostring(player_index)
end

local function format_hours(ticks)
    return string.format('%.1f', math.max(0, ticks) / config.ticks_per_hour)
end

local function render_players_page(viewer, frame, content)
    local actions = content.add{
        type = 'flow',
        name = PLAYER_ACTIONS_NAME,
        direction = 'horizontal',
    }
    actions.add{
        type = 'button',
        caption = {'un.friend-remove-offline'},
        tags = {action = 'friend-remove-offline'},
    }
    local list = content.add{
        type = 'table',
        name = PLAYER_TABLE_NAME,
        column_count = 6,
    }
    list.add{type = 'label', caption = {'un.player-column-status'}}
    list.add{type = 'label', caption = {'un.player-column-name'}}
    list.add{type = 'label', caption = {'un.player-column-online-hours'}}
    list.add{type = 'label', caption = {'un.player-column-offline-hours'}}
    list.add{type = 'label', caption = {'un.player-column-locale'}}
    list.add{type = 'label', caption = {'un.player-column-friend'}}

    local players = {}
    for _, player in pairs(game.players) do players[#players + 1] = player end
    table.sort(players, function(a, b)
        if a.connected ~= b.connected then return a.connected end
        if a.name ~= b.name then return a.name < b.name end
        return a.index < b.index
    end)
    for _, player in ipairs(players) do
        list.add{type = 'label', name = player_element_name('status', player.index)}
        list.add{type = 'label', caption = player.name}
        list.add{type = 'label', name = player_element_name('online', player.index)}
        list.add{type = 'label', name = player_element_name('offline', player.index)}
        list.add{type = 'label', name = player_element_name('locale', player.index)}
        if player.index == viewer.index then
            list.add{type = 'label', caption = ''}
        else
            local added = social.is_friend(viewer.index, player.index)
            list.add{
                type = 'button',
                caption = added and {'un.friend-remove'} or {'un.friend-add'},
                tags = {
                    action = added and 'friend-remove' or 'friend-add',
                    target_index = player.index,
                },
            }
        end
    end
    set_frame_state(frame, 'players')
    local tags = frame.tags
    tags.player_signature = player_signature()
    frame.tags = tags
end

local function render_page(player, page)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then return end
    local content = frame[CONTENT_NAME]
    if not (content and content.valid) then return end
    content.clear()

    if page == 'help' then
        render_help_page(frame, content)
    elseif page == 'overview' then
        render_overview_page(player, frame, content)
    elseif page == 'property' then
        render_property_table(player, frame, content)
    elseif page == 'players' then
        render_players_page(player, frame, content)
    else
        page = 'help'
        render_help_page(frame, content)
    end

    local navigation = frame[NAVIGATION_NAME]
    navigation[NAV_HELP_NAME].enabled = page ~= 'help'
    navigation[NAV_UBI_NAME].enabled = page ~= 'overview'
    navigation[NAV_PROPERTY_NAME].enabled = page ~= 'property'
    navigation[NAV_PLAYERS_NAME].enabled = page ~= 'players'
end

local function property_error(err)
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'renew-limit' then return {'un.property-error-renew-limit'} end
    if err == 'price-increased' then return {'un.property-error-price-changed'} end
    if err == 'not-owner' or err == 'already-owner' then
        return {'un.property-error-ownership'}
    end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'travel-restricted' then return {'un.travel-restricted'} end
    if err == 'planet-closed' then return {'un.travel-planet-closed'} end
    if err == 'ship-home-restricted' then return {'un.ship-home-restricted'} end
    if err == 'ship-already-have' then return {'un.ship-already-have'} end
    if err == 'ship-missing' then return {'un.ship-missing'} end
    if err == 'ship-not-ready' then return {'un.ship-not-ready'} end
    if err == 'ship-create-failed' then return {'un.ship-create-failed'} end
    return {'un.property-error-unavailable'}
end

local function property_disappeared(err)
    return err == 'missing' or err == 'surface-missing'
end

local DRAGGABLE_TYPES = {
    flow = true,
    frame = true,
    label = true,
    table = true,
    ['empty-widget'] = true,
}

local function make_frame_draggable(element, frame)
    for _, child in pairs(element.children) do
        if DRAGGABLE_TYPES[child.type] then child.drag_target = frame end
        make_frame_draggable(child, frame)
    end
end

local function update_property_row(player, property_table, property)
    local price = property_table[property_price_name(property.id)]
    if price and price.valid then
        price.caption = format_integer(properties.current_price(property))
    end

    local owns = property.owner_index == player.index
    local can_buy, buy_error
    if owns then
        can_buy, buy_error = properties.renew_availability(player, property)
    else
        can_buy, buy_error = properties.buy_availability(player, property)
    end
    local buy = property_table[property_buy_name(property.id)]
    if buy and buy.valid then
        buy.enabled = can_buy
        buy.tooltip = can_buy and (owns and {'un.property-renew-tooltip'}
            or {'un.property-buy'})
            or disabled_tooltip(owns and 'renew' or 'buy', buy_error)
        if buy.tags.action ~= 'property-confirm-buy' then
            buy.caption = owns and {
                'un.property-renew',
                format_integer(properties.renew_fee(property)),
            } or {'un.property-buy'}
            buy.tags = {
                action = owns and 'property-renew' or 'property-buy',
                property_id = property.id,
            }
        end
    end

    local can_enter, enter_error = properties.enter_availability(player, property)
    local enter = property_table[property_enter_name(property.id)]
    if enter and enter.valid then
        enter.enabled = can_enter
        enter.tooltip = can_enter and {'un.property-enter'}
            or disabled_tooltip('enter', enter_error)
    end
end

local function update_frame(player)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then
        open_players[player.index] = nil
        return
    end
    local content = frame[CONTENT_NAME]
    if not (content and content.valid) then return end
    local page = frame.tags.page or 'overview'

    if page == 'overview' then
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
        local platform, record = ships.of(player.index)
        local status = content[SHIP_STATUS_NAME]
        local ship_actions = content[SHIP_ACTIONS_NAME]
        local create = ship_actions[SHIP_CREATE_NAME]
        local scuttle = ship_actions[SHIP_SCUTTLE_NAME]
        if platform then
            local hours = math.ceil(math.max(0, ships.left_ticks(record))
                / config.ticks_per_hour)
            status.caption = {'un.ship-status', platform.name, hours}
            create.enabled = false
            scuttle.enabled = true
        else
            status.caption = {'un.ship-none'}
            create.enabled = true
            scuttle.enabled = false
        end
        local data = experience.get(player.index)
        local grid = content[EXPERIENCE_TABLE_NAME]
        for index, name in ipairs(config.science_pack_order) do
            local amount = data[name] or 0
            local threshold = experience.next_threshold(amount)
            local progress = grid[experience_progress_name(index)]
            local label = grid[experience_amount_name(index)]
            if progress and progress.valid then
                progress.value = math.max(0, math.min(1, amount / threshold))
            end
            if label and label.valid then
                label.caption = {
                    'un.experience-amount',
                    format_integer(amount),
                    format_integer(threshold),
                    experience.contribution(amount),
                }
            end
        end
        local summary = content[EXPERIENCE_SUMMARY_NAME]
        if summary and summary.valid then
            summary.caption = {
                'un.experience-summary',
                experience.total_level(player.index),
            }
        end
    elseif page == 'property' then
        if (frame.tags.property_revision or -1) ~= (storage.property_revision or 0) then
            render_property_table(player, frame, content)
        else
            local property_table = content[PROPERTY_TABLE_NAME]
            if property_table and property_table.valid then
                for _, property in ipairs(properties.list()) do
                    update_property_row(player, property_table, property)
                end
            end
        end
    elseif page == 'players' then
        if frame.tags.player_signature ~= player_signature() then
            content.clear()
            render_players_page(player, frame, content)
        end
        local list = content[PLAYER_TABLE_NAME]
        if list and list.valid then
            for _, listed_player in pairs(game.players) do
                local status = list[player_element_name('status', listed_player.index)]
                local online = list[player_element_name('online', listed_player.index)]
                local offline = list[player_element_name('offline', listed_player.index)]
                local locale = list[player_element_name('locale', listed_player.index)]
                if status and status.valid then
                    status.caption = listed_player.connected
                        and {'un.player-online'} or {'un.player-offline'}
                end
                if online and online.valid then
                    online.caption = format_hours(listed_player.online_time)
                end
                if offline and offline.valid then
                    local account = economy.ensure_account(listed_player.index)
                    local observed_ticks = math.max(
                        0,
                        game.tick - (account.created_tick or game.tick)
                    )
                    local offline_ticks = math.max(
                        0,
                        observed_ticks - listed_player.online_time
                    )
                    offline.caption = format_hours(offline_ticks)
                end
                if locale and locale.valid then locale.caption = listed_player.locale end
            end
        end
    end
    if not frame.tags.drag_ready then
        make_frame_draggable(frame, frame)
        local tags = frame.tags
        tags.drag_ready = true
        frame.tags = tags
    end
end

local function close_frame(player)
    open_players[player.index] = nil
    local frame = player.gui.screen[FRAME_NAME]
    if frame and frame.valid then frame.destroy() end
end

local function open_frame(player, initial_page)
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
    navigation.add{type = 'button', name = NAV_HELP_NAME, caption = {'un.page-help'}}
    navigation.add{type = 'button', name = NAV_UBI_NAME, caption = {'un.page-overview'}}
    navigation.add{type = 'button', name = NAV_PROPERTY_NAME, caption = {'un.page-property'}}
    navigation.add{type = 'button', name = NAV_PLAYERS_NAME, caption = {'un.page-players'}}

    local tab_gap = frame.add{type = 'empty-widget'}
    tab_gap.style.height = 12
    tab_gap.drag_target = frame

    local content = frame.add{
        type = 'flow',
        name = CONTENT_NAME,
        direction = 'vertical',
    }
    content.style.horizontally_stretchable = true

    render_page(player, initial_page or 'help')
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
    if element.name == HUD_HELP_NAME then
        open_frame(player, 'help')
    elseif element.name == HUD_UBI_NAME then
        open_frame(player, 'overview')
    elseif element.name == HUD_LAST_PROPERTY_NAME then
        local ok, err = properties.enter_last_owned(player)
        if not ok then player.print(property_error(err)) end
    elseif element.name == HUD_PROPERTY_NAME then
        open_frame(player, 'property')
    elseif element.name == HUD_PLAYERS_NAME then
        open_frame(player, 'players')
    elseif element.name == CLOSE_NAME then
        close_frame(player)
    elseif element.name == NAV_HELP_NAME then
        render_page(player, 'help')
        update_frame(player)
    elseif element.name == HELP_BRIEF_NAME
            or element.name == HELP_ADVANCED_NAME
            or element.name == HELP_FULL_NAME then
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if not (content and content.valid) then return end
        local mode = element.name == HELP_FULL_NAME and 'full'
            or element.name == HELP_ADVANCED_NAME and 'advanced' or 'brief'
        content.clear()
        render_help_page(frame, content, mode)
        update_frame(player)
    elseif element.name == NAV_UBI_NAME then
        render_page(player, 'overview')
        update_frame(player)
    elseif element.name == NAV_PROPERTY_NAME then
        render_page(player, 'property')
        update_frame(player)
    elseif element.name == NAV_PLAYERS_NAME then
        render_page(player, 'players')
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
    elseif element.name == SHIP_CREATE_NAME then
        local platform, err = ships.create(player)
        if not platform then player.print(property_error(err)) end
        render_page(player, 'overview')
        update_frame(player)
    elseif element.name == SHIP_SCUTTLE_NAME then
        if element.tags.action == 'ship-scuttle-confirm' then
            local ok, err = ships.scuttle(player)
            if not ok then player.print(property_error(err)) end
            render_page(player, 'overview')
            update_frame(player)
        else
            element.caption = {'un.ship-scuttle-confirm'}
            element.tags = {action = 'ship-scuttle-confirm'}
        end
    elseif element.name == SUICIDE_NAME then
        if element.tags.action == 'suicide-confirm' then
            close_frame(player)
            local ok = surfaces.suicide(player)
            if not ok then player.print({'un.suicide-unavailable'}) end
        else
            element.sprite = 'utility/confirm_slot'
            element.tooltip = {'un.suicide-confirm'}
            element.tags = {action = 'suicide-confirm'}
        end
    else
        local tags = element.tags
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if not (content and content.valid) then return end
        if tags.action == 'property-buy' then
            local property = properties.get(tags.property_id)
            if not property then
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
        elseif tags.action == 'friend-add' then
            local ok, result = social.add_friend(player.index, tags.target_index)
            local target = game.get_player(tags.target_index)
            if not ok and result == 'limit' then
                player.print({'un.friend-limit', config.friend_limit})
            elseif ok and result == true and target then
                player.print({'un.friend-mutual', target.name})
                if target.connected then
                    target.print({'un.friend-mutual', player.name})
                end
            end
            render_page(player, 'players')
            update_frame(player)
        elseif tags.action == 'friend-remove' then
            social.remove_friend(player.index, tags.target_index)
            render_page(player, 'players')
            update_frame(player)
        elseif tags.action == 'friend-remove-offline' then
            local removed = social.remove_offline_friends(player.index)
            player.print({'un.friend-removed-offline', removed})
            render_page(player, 'players')
            update_frame(player)
        elseif tags.action == 'property-confirm-buy' then
            local ok, err = properties.buy(player, tags.property_id, tags.quoted_price)
            if not ok and not property_disappeared(err) then
                player.print(property_error(err))
            end
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action == 'property-renew' then
            local ok, err = properties.renew(player, tags.property_id)
            if not ok and not property_disappeared(err) then
                player.print(property_error(err))
            end
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action == 'property-enter' then
            local ok, err = properties.enter(player, tags.property_id)
            if ok then close_frame(player)
            elseif not property_disappeared(err) then
                player.print(property_error(err))
            else
                render_property_table(player, frame, content)
            end
        end
    end
end)

events.on(defines.events.on_gui_switch_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if element.name == PROPERTY_ACCESS_NAME then
        if properties.owned_count(player.index) > 0 then
            properties.set_all_open(player.index, element.switch_state == 'right')
        else
            local frame = player.gui.screen[FRAME_NAME]
            local content = frame and frame.valid and frame[CONTENT_NAME]
            if content and content.valid then
                render_property_table(player, frame, content)
            end
        end
        return
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
