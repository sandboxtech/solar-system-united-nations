local config = require('config')
local crime = require('scripts.crime')
local disasters = require('scripts.disasters')
local economy = require('scripts.economy')
local events = require('scripts.events')
local experience = require('scripts.experience')
local factions = require('scripts.factions')
local permissions = require('scripts.permissions')
local playtime = require('scripts.playtime')
local properties = require('scripts.properties')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local ships = require('scripts.ships')
local social = require('scripts.social')
local stamina = require('scripts.stamina')
local starter = require('scripts.starter')
local surfaces = require('scripts.surfaces')
local technology_decay = require('scripts.technology_decay')

local M = {}

local HUD_FLOW_NAME = 'un_hud_flow'
local HUD_LAYOUT_VERSION = 13
local LEGACY_BUTTON_NAME = 'un_main_button'
local HUD_TITLE_NAME = 'un_hud_title'
local HUD_MENU_NAME = 'un_hud_menu'
local HUD_LAST_PROPERTY_NAME = 'un_hud_last_property'
local FRAME_NAME = 'un_main_frame'
local CLOSE_NAME = 'un_main_close'
local CONTENT_NAME = 'un_main_content'
local NAVIGATION_NAME = 'un_main_navigation'
local NAV_HELP_NAME = 'un_nav_help'
local NAV_UBI_NAME = 'un_nav_ubi'
local NAV_PROPERTY_BUILD_NAME = 'un_nav_property_build'
local NAV_PROPERTY_NAME = 'un_nav_property'
local NAV_PLANETS_NAME = 'un_nav_planets'
local NAV_SHIPS_NAME = 'un_nav_ships'
local NAV_PLAYERS_NAME = 'un_nav_players'
local NAV_FACTIONS_NAME = 'un_nav_factions'
local NAV_ADMIN_NAME = 'un_nav_admin'
local HELP_STORY_NAME = 'un_help_story'
local HELP_BRIEF_NAME = 'un_help_brief'
local HELP_ADVANCED_NAME = 'un_help_advanced'
local HELP_FULL_NAME = 'un_help_full'
local HELP_ADMIN_NAME = 'un_help_admin'
local HELP_DETAILS_NAME = 'un_help_details'
local PROPERTY_ACCESS_NAME = 'un_property_access'
local PROPERTY_ACCESS_SECTION_NAME = 'un_property_access_section'
local PROPERTY_HEADER_NAME = 'un_property_header'
local PROPERTY_HOSPICE_BUTTON_NAME = 'un_property_hospice_button'
local PROPERTY_SALVAGE_BUTTON_NAME = 'un_property_salvage_button'
local BALANCE_TABLE_NAME = 'un_ubi_balance_table'
local BALANCE_NAME = 'un_ubi_balance'
local STAMINA_NAME = 'un_stamina'
local UBI_PROGRESS_NAME = 'un_ubi_progress'
local UBI_CLAIM_NAME = 'un_ubi_claim'
local STARTER_KIT_NAME = 'un_starter_kit'
local WOOD_SUPPLY_NAME = 'un_wood_supply'
local SHIP_STATUS_NAME = 'un_ship_status'
local SHIP_ACTIONS_NAME = 'un_ship_actions'
local SHIP_CREATE_NAME = 'un_ship_create'
local SHIP_SCUTTLE_NAME = 'un_ship_scuttle'
local SHIP_SCROLL_NAME = 'un_ship_scroll'
local SHIP_TABLE_NAME = 'un_ship_table'
local PROPERTY_SCROLL_NAME = 'un_property_scroll'
local PROPERTY_TABLE_NAME = 'un_property_table'
local PROPERTY_BUILD_FORM_NAME = 'un_property_build_form'
local PROPERTY_BUILD_NAME_NAME = 'un_property_build_name'
local PROPERTY_BUILD_LIFETIME_NAME = 'un_property_build_lifetime'
local PROPERTY_BUILD_SIZE_NAME = 'un_property_build_size'
local PROPERTY_BUILD_COST_NAME = 'un_property_build_cost'
local PROPERTY_BUILD_AVAILABLE_NAME = 'un_property_build_available'
local PROPERTY_BUILD_STAMINA_COST_NAME = 'un_property_build_stamina_cost'
local PROPERTY_BUILD_STAMINA_AVAILABLE_NAME = 'un_property_build_stamina_available'
local PROPERTY_BUILD_BUTTON_NAME = 'un_property_build_button'
local EXPERIENCE_SUMMARY_NAME = 'un_experience_summary'
local EXPERIENCE_TABLE_NAME = 'un_experience_table'
local PLAYER_ACTIONS_NAME = 'un_player_actions'
local PLAYER_SCROLL_NAME = 'un_player_scroll'
local PLAYER_TABLE_NAME = 'un_player_table'
local PLANET_HEADER_NAME = 'un_planet_header'
local PLANET_TABLE_NAME = 'un_planet_table'
local TECH_LEAK_COUNTDOWN_NAME = 'un_tech_leak_countdown'
local CRIME_ACTIONS_NAME = 'un_crime_actions'
local CRIME_STATUS_NAME = 'un_crime_status'
local CRIME_BUTTON_NAME = 'un_crime_button'
local FACTION_TABLE_NAME = 'un_faction_table'
local FACTION_SWITCH_PREFIX = 'un_faction_switch_'
local ADMIN_SCROLL_NAME = 'un_admin_scroll'
local ADMIN_SETTINGS_TABLE_NAME = 'un_admin_settings_table'
local ADMIN_PLAYER_TABLE_NAME = 'un_admin_player_table'
local ADMIN_PROPERTY_TABLE_NAME = 'un_admin_property_table'

local ADMIN_NUMBER_SETTINGS = {
    {'initial_coin', 'un.admin-setting-initial-coin'},
    {'friend_limit', 'un.admin-setting-friend-limit'},
    {'ship_life_hours', 'un.admin-setting-ship-life'},
    {'faction_switch_min_online_hours', 'un.admin-setting-faction-online-hours'},
    {'crime_min_online_hours', 'un.admin-setting-crime-online-hours'},
    {'ship_build_min_online_hours', 'un.admin-setting-ship-online-hours'},
    {'deconstruction_min_online_hours', 'un.admin-setting-deconstruction-online-hours'},
    {'cleanup_idle_hours', 'un.admin-setting-cleanup-hours'},
    {'planet_reset_min_hours', 'un.admin-setting-planet-reset-min'},
    {'planet_reset_max_hours', 'un.admin-setting-planet-reset-max'},
    {'planet_reset_exponent', 'un.admin-setting-planet-reset-exponent'},
    {'property_tax_percent', 'un.admin-setting-property-tax'},
    {'property_price_factor', 'un.admin-setting-property-factor'},
    {'technology_price_multiplier', 'un.admin-setting-technology-price'},
    {'spoil_time_modifier', 'un.admin-setting-spoil-time'},
    {'asteroid_spawning_rate', 'un.admin-setting-asteroid-rate'},
    {'property_limit_per_planet', 'un.admin-setting-property-limit'},
    {'property_build_price_multiplier', 'un.admin-setting-property-build-price'},
    {'property_salvage_percent', 'un.admin-setting-property-salvage'},
    {'property_lifetime_1_hours', 'un.admin-setting-property-lifetime-1'},
    {'property_lifetime_2_hours', 'un.admin-setting-property-lifetime-2'},
    {'property_lifetime_3_hours', 'un.admin-setting-property-lifetime-3'},
    {'property_decay_1_hours', 'un.admin-setting-property-decay-1'},
    {'property_decay_2_hours', 'un.admin-setting-property-decay-2'},
    {'property_decay_3_hours', 'un.admin-setting-property-decay-3'},
    {'tech_leak_interval_hours', 'un.admin-setting-tech-leak-interval'},
    {'tech_leak_max_percent', 'un.admin-setting-tech-leak-strength'},
}

local crime_error_caption
local update_crime_action

local PERSONAL_ACTION_WIDTH = 300
local LIST_SCROLL_MAX_HEIGHT = 520
local PROPERTY_SORT_FIELDS = {
    name = true,
    owner = true,
    expiry = true,
    price = true,
    change = true,
    period = true,
}

local function add_list_scroll(content, name)
    local scroll = content.add{type = 'scroll-pane', name = name}
    scroll.style.maximal_height = LIST_SCROLL_MAX_HEIGHT
    scroll.style.horizontally_stretchable = true
    return scroll
end

local function table_in_scroll(content, scroll_name, table_name)
    local scroll = content[scroll_name]
    if scroll and scroll.valid then return scroll[table_name] end
    -- Keep already-open windows from older scenario code safe until rebuilt.
    return content[table_name]
end

local function update_home_button(player, hud)
    hud = hud or player.gui.top[HUD_FLOW_NAME]
    local button = hud and hud.valid and hud[HUD_LAST_PROPERTY_NAME]
    if not (button and button.valid) then return end
    local planet_name = factions.of_player(player)
    if planet_name and player.physical_surface.name == planet_name then
        button.tooltip = {'un.hud-home-to-home-tooltip'}
    else
        button.tooltip = {'un.hud-home-to-planet-tooltip'}
    end
end

local function format_integer(value)
    local raw = string.format('%.0f', value)
    local sign, digits = raw:match('^([%-]?)(%d+)$')
    if not digits then return raw end
    local reversed = digits:reverse():gsub('(%d%d%d)', '%1,')
    local grouped = reversed:reverse():gsub('^,', '')
    return sign .. grouped
end

local function add_info_sprite(parent, tooltip)
    local info = parent.add{
        type = 'sprite',
        sprite = 'info',
        tooltip = tooltip,
    }
    info.style.width = 20
    info.style.height = 20
    return info
end

local function ship_create_tooltip()
    return {
        'un.ship-create-tooltip',
        settings.get('ship_life_hours'),
        config.ship_base_width,
        config.ship_width_per_level,
        config.ship_height,
    }
end

local function sorted_players(viewer_index)
    local result = {}
    for _, player in pairs(game.players) do result[#result + 1] = player end
    table.sort(result, function(a, b)
        local a_self = a.index == viewer_index
        local b_self = b.index == viewer_index
        if a_self ~= b_self then return a_self end
        if a.connected ~= b.connected then return a.connected end
        if not a.connected then
            local a_account = storage.players[a.index]
            local b_account = storage.players[b.index]
            local a_seen = a_account and a_account.last_seen_tick
                or a.last_online or 0
            local b_seen = b_account and b_account.last_seen_tick
                or b.last_online or 0
            if a_seen ~= b_seen then return a_seen > b_seen end
        end
        local a_name = string.lower(a.name)
        local b_name = string.lower(b.name)
        if a_name ~= b_name then return a_name < b_name end
        if a.name ~= b.name then return a.name < b.name end
        return a.index < b.index
    end)
    return result
end

function M.ensure_button(player)
    local root = player.gui.top
    local old = root[LEGACY_BUTTON_NAME]
    if old and old.valid then old.destroy() end

    local hud = root[HUD_FLOW_NAME]
    if hud and hud.valid then
        local complete = hud.tags.layout_version == HUD_LAYOUT_VERSION
            and hud[HUD_TITLE_NAME]
            and hud[HUD_MENU_NAME]
            and hud[HUD_LAST_PROPERTY_NAME]
        if complete then
            hud[HUD_TITLE_NAME].caption = {'un.hud-title'}
            update_home_button(player, hud)
            return hud
        end
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
    title.style.font = 'default-large-bold'
    title.style.font_color = {r = 1, g = 1, b = 1}
    title.style.height = 40
    title.style.horizontal_align = 'center'
    title.style.vertical_align = 'center'
    title.style.left_margin = 4
    title.style.right_margin = 6
    local buttons = {
        {HUD_MENU_NAME, {'un.hud-action-button'}, {'un.hud-menu-tooltip'}},
        {HUD_LAST_PROPERTY_NAME, {'un.hud-travel-button'}, {'un.hud-home-tooltip'}},
    }
    for _, spec in ipairs(buttons) do
        local button = hud.add{
            type = 'button',
            name = spec[1],
            caption = spec[2],
            tooltip = spec[3],
        }
        button.style.height = 40
        button.style.minimal_width = 88
    end
    update_home_button(player, hud)
    return hud
end

local function property_price_name(property_id)
    return 'un_property_price_' .. tostring(property_id)
end

local function property_price_change_name(property_id)
    return 'un_property_price_change_' .. tostring(property_id)
end

local function property_price_change_caption(property, current_price)
    local change = current_price - property.base_price
    if change > 0 then
        return {'un.property-price-change-up', format_integer(change)}
    end
    if change < 0 then
        return {'un.property-price-change-down', format_integer(-change)}
    end
    return {'un.property-price-change-same'}
end

local function property_buy_name(property_id)
    return 'un_property_buy_' .. tostring(property_id)
end

local function property_enter_name(property_id)
    return 'un_property_enter_' .. tostring(property_id)
end

local function property_remaining_name(property_id)
    return 'un_property_remaining_' .. tostring(property_id)
end

local function disabled_tooltip(action, err)
    if err == 'surface-missing' or err == 'missing' then
        return {'un.property-error-unavailable'}
    end
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'travel-restricted' then return {'un.travel-restricted'} end
    if err == 'planet-closed' then return {'un.travel-planet-closed'} end
    if err == 'wrong-faction' then return {'un.property-error-wrong-faction'} end
    if action == 'enter' and err == 'not-owner' then
        return {'un.property-enter-disabled-private'}
    end
    if action == 'salvage' and err == 'not-owner' then
        return {'un.property-salvage-not-owner'}
    end
    if action == 'salvage' and err == 'permanent' then
        return {'un.property-salvage-permanent'}
    end
    if action == 'salvage' and err == 'not-player-built' then
        return {'un.property-salvage-unavailable'}
    end
    if action == 'salvage' and err == 'not-inside' then
        return {'un.property-salvage-not-inside'}
    end
    return {'un.property-error-unavailable'}
end

local function experience_progress_name(index)
    return 'un_experience_progress_' .. tostring(index)
end

local function experience_amount_name(index)
    return 'un_experience_amount_' .. tostring(index)
end

local function ship_remaining_name(platform_index)
    return 'un_ship_remaining_' .. tostring(platform_index)
end

local function planet_countdown_name(name)
    return 'un_planet_countdown_' .. name
end

local function planet_traits_name(name)
    return 'un_planet_traits_' .. name
end

local function render_planet_traits(container, item)
    local signature = tostring(item.round or 0)
        .. ':' .. table.concat(item.traits, '|')
    if container.tags.trait_signature == signature then return end
    container.clear()
    if #item.traits == 0 then
        container.add{
            type = 'label',
            caption = item.round and item.round > 0
                and {'un.planet-traits-none'}
                or {'un.planet-traits-pending'},
        }
    else
        for _, trait_id in ipairs(item.traits) do
            container.add{
                type = 'label',
                caption = {'un.planet-trait-name-' .. trait_id},
                tooltip = {'un.planet-trait-' .. trait_id},
            }
        end
    end
    container.tags = {trait_signature = signature}
end

local function admin_setting_input_name(key)
    return 'un_admin_setting_' .. key
end

local function admin_balance_input_name(player_index)
    return 'un_admin_balance_' .. tostring(player_index)
end

local function planet_label(name)
    return {'', '[planet=' .. name .. '] ', {'space-location-name.' .. name}}
end

local function format_countdown(ticks)
    local seconds = math.max(0, math.ceil((ticks or 0) / config.ticks_per_second))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainder = seconds % 60
    return string.format('%02d:%02d:%02d', hours, minutes, remainder)
end

local function online_requirement_caption(player, setting_key, locale_key)
    return {
        locale_key,
        settings.get(setting_key),
        format_countdown(settings.online_requirement_left_ticks(
            player,
            setting_key
        )),
    }
end

local function property_lifetime_caption(property)
    if property.permanent then return {'un.property-permanent'} end
    return format_countdown(properties.left_ticks(property))
end

local function set_frame_state(frame, page, property_revision)
    local tags = frame.tags
    tags.page = page
    tags.property_revision = property_revision or -1
    tags['list_refresh_' .. page] = nil
    frame.tags = tags
end

local function property_sort_state(frame)
    local field = frame.tags.property_sort_field
    if not PROPERTY_SORT_FIELDS[field] then field = 'expiry' end
    return field, frame.tags.property_sort_descending == true
end

local function property_sort_name(property)
    if type(property.custom_name) == 'string' then
        return string.lower(property.custom_name)
    end
    local owner = properties.owner_name(property) or ''
    local number = property.owner_index and property.owner_property_number
        or property.planet_property_number or property.id
    return string.lower(owner) .. string.format('\0%012d', number or 0)
end

local function sort_properties(property_list, field, descending)
    local values = {}
    for _, property in ipairs(property_list) do
        local price = properties.current_price(property)
        if field == 'name' then
            values[property.id] = property_sort_name(property)
        elseif field == 'owner' then
            values[property.id] = string.lower(
                properties.owner_name(property) or ''
            )
        elseif field == 'price' then
            values[property.id] = price
        elseif field == 'change' then
            values[property.id] = price - property.base_price
        elseif field == 'period' then
            values[property.id] = property.decay_ticks
        else
            values[property.id] = property.expires_tick or math.huge
        end
    end
    table.sort(property_list, function(a, b)
        local a_value = values[a.id]
        local b_value = values[b.id]
        if a_value ~= b_value then
            if descending then return a_value > b_value end
            return a_value < b_value
        end
        return a.id < b.id
    end)
end

local function add_property_sort_header(list, frame, field, caption)
    local selected, descending = property_sort_state(frame)
    local button = list.add{
        type = 'button',
        caption = caption,
        tooltip = selected == field and {
            descending and 'un.property-sort-descending-tooltip'
                or 'un.property-sort-ascending-tooltip',
        } or {'un.property-sort-column-tooltip'},
        tags = {action = 'property-sort-column', field = field},
    }
    button.style.horizontally_stretchable = true
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
        tooltip = {'un.property-access-tooltip'},
    }
end

local function update_property_salvage_action(player, content)
    local actions = content[CRIME_ACTIONS_NAME]
    local button = actions and actions.valid
        and actions[PROPERTY_SALVAGE_BUTTON_NAME]
    if not (button and button.valid) then return end
    local available, err, property, value
        = properties.salvage_at_player_availability(player)
    button.enabled = available
    button.tooltip = available and {
        'un.property-salvage-tooltip',
        settings.get('property_salvage_percent'),
        format_integer(value),
    } or {
        '',
        disabled_tooltip('salvage', err),
        '\n\n',
        {
            'un.property-salvage-rule-tooltip',
            settings.get('property_salvage_percent'),
        },
    }
    if not available or button.tags.action ~= 'property-confirm-salvage'
            or button.tags.property_id ~= property.id then
        button.caption = {'un.property-salvage'}
        button.tags = {
            action = 'property-salvage',
            property_id = property and property.id or 0,
        }
    end
end

local function update_property_hospice_action(player, content)
    local actions = content[CRIME_ACTIONS_NAME]
    local button = actions and actions.valid
        and actions[PROPERTY_HOSPICE_BUTTON_NAME]
    if not (button and button.valid) then return end
    local available, err = properties.hospice_travel_availability(player)
    button.enabled = available
    button.tooltip = available and {'un.travel-hospice'}
        or disabled_tooltip('hospice', err)
end

local function render_property_table(player, frame, content)
    local old_header = content[PROPERTY_HEADER_NAME]
    if old_header and old_header.valid then old_header.destroy() end
    local old_crime = content[CRIME_ACTIONS_NAME]
    if old_crime and old_crime.valid then old_crime.destroy() end
    local old_access = content[PROPERTY_ACCESS_SECTION_NAME]
    if old_access and old_access.valid then old_access.destroy() end
    local old_scroll = content[PROPERTY_SCROLL_NAME]
    if old_scroll and old_scroll.valid then old_scroll.destroy() end
    local old = content[PROPERTY_TABLE_NAME]
    if old and old.valid then old.destroy() end
    local selected = factions.of_player(player) or 'nauvis'
    local tags = frame.tags
    tags.property_planet = selected
    frame.tags = tags
    local property_list = properties.list(selected)
    local sort_field, sort_descending = property_sort_state(frame)
    sort_properties(property_list, sort_field, sort_descending)
    local header = content.add{
        type = 'flow',
        name = PROPERTY_HEADER_NAME,
        direction = 'horizontal',
    }
    header.style.vertical_align = 'center'
    header.add{
        type = 'label',
        caption = {'un.property-current-faction', planet_label(selected)},
    }
    add_info_sprite(header, {'un.property-page-tooltip'})
    local crime_actions = content.add{
        type = 'table',
        name = CRIME_ACTIONS_NAME,
        column_count = 3,
    }
    if properties.owned_count(player.index, selected) > 0 then
        crime_actions.add{
            type = 'button',
            name = PROPERTY_HOSPICE_BUTTON_NAME,
            caption = {'un.travel-hospice'},
            tags = {action = 'property-travel-hospice'},
        }
    else
        crime_actions.add{type = 'label', caption = ''}
    end
    crime_actions.add{
        type = 'button',
        name = PROPERTY_SALVAGE_BUTTON_NAME,
        caption = {'un.property-salvage'},
        tags = {action = 'property-salvage', property_id = 0},
    }
    crime_actions.add{
        type = 'button',
        name = CRIME_BUTTON_NAME,
        caption = {
            'un.crime-button',
            config.crime_coin_cost,
            config.crime_stamina_cost,
        },
    }
    crime_actions.add{type = 'label', caption = ''}
    crime_actions.add{type = 'label', caption = ''}
    crime_actions.add{type = 'label', name = CRIME_STATUS_NAME}
    update_property_hospice_action(player, content)
    update_property_salvage_action(player, content)
    if properties.owned_count(player.index) > 0 then
        render_property_access_section(player, content)
    end
    local scroll = add_list_scroll(content, PROPERTY_SCROLL_NAME)
    local list = scroll.add{
        type = 'table',
        name = PROPERTY_TABLE_NAME,
        column_count = 8,
        style = 'bordered_table',
    }
    add_property_sort_header(
        list, frame, 'name', {'un.property-column-name'}
    )
    add_property_sort_header(
        list, frame, 'owner', {'un.property-column-owner'}
    )
    add_property_sort_header(
        list, frame, 'expiry', {'un.property-column-lifetime'}
    )
    add_property_sort_header(
        list, frame, 'price', {'un.property-column-price'}
    )
    add_property_sort_header(
        list, frame, 'change', {'un.property-column-price-change'}
    )
    add_property_sort_header(
        list, frame, 'period', {'un.property-column-price-period'}
    )
    list.add{type = 'label', caption = {'un.property-buy'}}
    list.add{type = 'label', caption = {'un.property-enter'}}

    for _, property in ipairs(property_list) do
        list.add{
            type = 'label',
            caption = properties.surface_display_name(property),
            tooltip = properties.feature_description(property),
        }
        local owner = properties.owner_name(property)
        list.add{
            type = 'label',
            caption = owner or {'un.property-vacant'},
        }
        list.add{
            type = 'label',
            name = property_remaining_name(property.id),
            caption = property_lifetime_caption(property),
        }
        local current_price = properties.current_price(property)
        list.add{
            type = 'label',
            name = property_price_name(property.id),
            caption = {'un.coin-amount',
                format_integer(current_price)},
        }
        list.add{
            type = 'label',
            name = property_price_change_name(property.id),
            caption = property_price_change_caption(property, current_price),
            tooltip = {'un.property-price-change-tooltip'},
        }
        list.add{
            type = 'label',
            caption = {
                'un.property-price-period-hours',
                tostring(property.decay_ticks / config.ticks_per_hour),
            },
            tooltip = {'un.property-price-period-tooltip'},
        }
        local can_buy, buy_error = properties.buy_availability(player, property)
        list.add{
            type = 'button',
            name = property_buy_name(property.id),
            caption = {'un.property-buy'},
            tooltip = can_buy and {'un.property-buy'}
                or disabled_tooltip('buy', buy_error),
            enabled = can_buy,
            tags = {
                action = 'property-buy',
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
    local tags = frame.tags
    tags.property_sort_field = sort_field
    tags.property_sort_descending = sort_descending
    tags.property_sort_bucket = math.floor(game.tick / config.ticks_per_minute)
    frame.tags = tags
    update_crime_action(player, content)
end

local function property_build_planet(player)
    return factions.of_player(player)
end

local function update_property_build_page(player, content)
    local form = content[PROPERTY_BUILD_FORM_NAME]
    if not (form and form.valid) then return end
    local planet_name = property_build_planet(player)
    local lifetime = form[PROPERTY_BUILD_LIFETIME_NAME]
    local size = form[PROPERTY_BUILD_SIZE_NAME]
    local cost_label = form[PROPERTY_BUILD_COST_NAME]
    local available_label = form[PROPERTY_BUILD_AVAILABLE_NAME]
    local stamina_cost_label = form[PROPERTY_BUILD_STAMINA_COST_NAME]
    local stamina_available_label = form[PROPERTY_BUILD_STAMINA_AVAILABLE_NAME]
    local button = form[PROPERTY_BUILD_BUTTON_NAME]
    if not (planet_name and lifetime and size and cost_label
            and available_label and stamina_cost_label and stamina_available_label
            and button) then return end
    local can_build, err, requirement = properties.build_availability(
        player,
        planet_name,
        lifetime.selected_index,
        size.selected_index
    )
    if not requirement then return end
    local pack_name = {'item-name.' .. requirement.pack}
    cost_label.caption = {
        'un.property-build-experience',
        '[img=item/' .. requirement.pack .. ']',
        pack_name,
        format_integer(requirement.experience_cost),
    }
    available_label.caption = {
        'un.property-build-experience',
        '[img=item/' .. requirement.pack .. ']',
        pack_name,
        format_integer(experience.amount(player.index, requirement.pack)),
    }
    stamina_cost_label.caption = format_integer(requirement.stamina_cost)
    stamina_available_label.caption = format_integer(stamina.get(player.index))
    button.enabled = can_build
    button.tooltip = can_build and {'un.property-build'}
        or err == 'property-limit' and {'un.property-build-limit'}
        or err == 'planet-closed' and {'un.travel-planet-closed'}
        or err == 'insufficient-stamina' and {'un.stamina-insufficient'}
        or {'un.property-build-insufficient-experience'}
    if button.tags.action ~= 'property-build-confirm' then
        button.caption = {'un.property-build'}
        button.tags = {action = 'property-build'}
    end
end

local function render_property_build_page(player, frame, content)
    local intro = content.add{
        type = 'label',
        caption = {'un.property-build-intro', config.property_build_stamina_cost},
    }
    intro.style.single_line = false
    intro.style.maximal_width = 680
    local form = content.add{
        type = 'table',
        name = PROPERTY_BUILD_FORM_NAME,
        column_count = 2,
        style = 'bordered_table',
    }
    form.add{type = 'label', caption = {'un.property-build-planet'}}
    local selected_planet = factions.of_player(player) or 'nauvis'
    form.add{type = 'label', caption = planet_label(selected_planet)}
    form.add{type = 'label', caption = {'un.property-build-name'}}
    form.add{
        type = 'textfield',
        name = PROPERTY_BUILD_NAME_NAME,
        tooltip = {
            'un.property-build-name-tooltip',
            config.property_name_max_characters,
        },
    }
    local lifetime_tooltip = {
        'un.property-build-lifetime-tooltip',
        settings.get('property_price_factor'),
    }
    form.add{
        type = 'label',
        caption = {'un.property-build-lifetime'},
        tooltip = lifetime_tooltip,
    }
    local lifetime_items = {}
    for _, option in ipairs(properties.build_lifetime_options()) do
        lifetime_items[#lifetime_items + 1] = {
            'un.property-build-lifetime-option',
            option.hours,
            option.decay_hours,
            option.cost_multiplier,
        }
    end
    form.add{
        type = 'drop-down',
        name = PROPERTY_BUILD_LIFETIME_NAME,
        items = lifetime_items,
        selected_index = 1,
        tooltip = lifetime_tooltip,
    }
    form.add{type = 'label', caption = {'un.property-build-size'}}
    local size_items = {}
    for _, option in ipairs(config.property_size_options) do
        size_items[#size_items + 1] = {
            'un.property-build-size-option',
            option.width,
            option.height,
        }
    end
    form.add{
        type = 'drop-down',
        name = PROPERTY_BUILD_SIZE_NAME,
        items = size_items,
        selected_index = 1,
    }
    form.add{type = 'label', caption = {'un.property-build-total'}}
    form.add{type = 'label', name = PROPERTY_BUILD_COST_NAME}
    form.add{type = 'label', caption = {'un.property-build-owned'}}
    form.add{type = 'label', name = PROPERTY_BUILD_AVAILABLE_NAME}
    form.add{type = 'label', caption = {'un.property-build-stamina-required'}}
    form.add{type = 'label', name = PROPERTY_BUILD_STAMINA_COST_NAME}
    form.add{type = 'label', caption = {'un.property-build-stamina-owned'}}
    form.add{type = 'label', name = PROPERTY_BUILD_STAMINA_AVAILABLE_NAME}
    form.add{type = 'label', caption = ''}
    form.add{
        type = 'button',
        name = PROPERTY_BUILD_BUTTON_NAME,
        caption = {'un.property-build'},
        tags = {action = 'property-build'},
    }
    set_frame_state(frame, 'property-build')
    update_property_build_page(player, content)
end

local function render_ubi_section(content)
    local ubi_tooltip = {
        'un.ubi-tooltip',
        config.ubi_credit_per_second,
        config.ubi_max_seconds / 3600,
        config.ubi_max_seconds * config.ubi_credit_per_second,
        settings.get('initial_coin'),
    }
    local stamina_tooltip = {
        'un.stamina-tooltip',
        config.stamina_per_second,
        config.stamina_max,
        config.fast_respawn_stamina_cost,
        config.fast_respawn_seconds,
        config.normal_respawn_seconds,
    }
    local coin_tooltip = {'un.coin-tooltip'}
    local balance = content.add{
        type = 'table',
        name = BALANCE_TABLE_NAME,
        column_count = 2,
        style = 'bordered_table',
    }
    balance.add{
        type = 'label',
        caption = {'un.credit-label'},
        tooltip = coin_tooltip,
    }
    balance.add{
        type = 'label',
        name = BALANCE_NAME,
        tooltip = coin_tooltip,
    }
    balance.add{
        type = 'label',
        caption = {'un.stamina-label'},
        tooltip = stamina_tooltip,
    }
    balance.add{
        type = 'label',
        name = STAMINA_NAME,
        tooltip = stamina_tooltip,
    }

    local progress = content.add{
        type = 'progressbar',
        name = UBI_PROGRESS_NAME,
        value = 0,
        tooltip = ubi_tooltip,
    }
    progress.style.width = PERSONAL_ACTION_WIDTH
    local claim = content.add{
        type = 'button',
        name = UBI_CLAIM_NAME,
        caption = {'un.ubi-claim', 0, economy.get_ubi_capacity()},
        tooltip = ubi_tooltip,
    }
    claim.style.width = PERSONAL_ACTION_WIDTH

    local kit = content.add{
        type = 'button',
        name = STARTER_KIT_NAME,
        caption = {
            'un.starter-kit-buy',
            config.starter_kit_equipment[2].count,
            config.starter_kit_items[1].count,
            config.starter_kit_stamina_cost,
        },
        tooltip = {'un.starter-kit-tooltip'},
        tags = {action = 'starter-kit-buy'},
    }
    kit.style.width = PERSONAL_ACTION_WIDTH

    local wood = content.add{
        type = 'button',
        name = WOOD_SUPPLY_NAME,
        caption = {
            'un.wood-supply-buy',
            config.wood_supply_count,
            config.wood_supply_stamina_cost,
        },
        tooltip = {
            'un.wood-supply-tooltip',
            config.wood_supply_count,
            config.wood_supply_stamina_cost,
        },
        tags = {action = 'wood-supply-buy'},
    }
    wood.style.width = PERSONAL_ACTION_WIDTH
end

local function render_ship_actions(player, content)
    content.add{
        type = 'label',
        caption = {'un.ship-faction-orbit',
            planet_label(factions.of_player(player) or 'nauvis')},
    }
    local ship_actions = content.add{
        type = 'flow',
        name = SHIP_ACTIONS_NAME,
        direction = 'horizontal',
    }
    ship_actions.add{
        type = 'button',
        name = SHIP_CREATE_NAME,
        caption = {'un.ship-create', format_integer(config.ship_stamina_cost)},
        tooltip = ship_create_tooltip(),
    }
    ship_actions.add{
        type = 'button',
        name = SHIP_SCUTTLE_NAME,
        caption = {'un.ship-scuttle'},
        tooltip = {'un.ship-scuttle-tooltip'},
    }
    content.add{type = 'label', name = SHIP_STATUS_NAME}
end

local function render_experience_section(content)
    local heading = content.add{type = 'flow', direction = 'horizontal'}
    heading.style.vertical_align = 'center'
    heading.add{type = 'label', caption = {'un.experience-title'}}
    add_info_sprite(heading, {'un.experience-tooltip'})
    local grid = content.add{
        type = 'table',
        name = EXPERIENCE_TABLE_NAME,
        column_count = 3,
        style = 'bordered_table',
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
    render_experience_section(content)
    set_frame_state(frame, 'overview')
    local tags = frame.tags
    tags.list_refresh_experience = nil
    frame.tags = tags
end


local function ship_signature(list)
    local parts = {}
    for _, item in ipairs(list) do
        parts[#parts + 1] = table.concat({
            item.index,
            item.owner_index,
            item.record.built_tick or 0,
            item.platform.name,
        }, ':')
    end
    return table.concat(parts, ',')
end

local function render_ships_page(player, frame, content)
    render_ship_actions(player, content)
    content.add{type = 'line'}
    local list_data = ships.list()
    local scroll = add_list_scroll(content, SHIP_SCROLL_NAME)
    local list = scroll.add{
        type = 'table',
        name = SHIP_TABLE_NAME,
        column_count = 4,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.ship-column-owner'}}
    list.add{type = 'label', caption = {'un.ship-column-name'}}
    list.add{type = 'label', caption = {'un.ship-column-orbit'}}
    list.add{type = 'label', caption = {'un.ship-column-remaining'}}
    if #list_data == 0 then
        list.add{type = 'label', caption = {'un.ship-list-empty'}}
        list.add{type = 'label', caption = ''}
        list.add{type = 'label', caption = ''}
        list.add{type = 'label', caption = ''}
    else
        for _, item in ipairs(list_data) do
            local owner = game.get_player(item.owner_index)
            local account = storage.players[item.owner_index]
            list.add{
                type = 'label',
                caption = owner and owner.name
                    or account and account.name
                    or ('#' .. item.owner_index),
            }
            list.add{type = 'label', caption = item.platform.name}
            list.add{
                type = 'label',
                caption = planet_label(item.record.planet_name
                    or config.ship_home_planet),
            }
            list.add{
                type = 'label',
                name = ship_remaining_name(item.index),
            }
        end
    end
    set_frame_state(frame, 'ships')
    local tags = frame.tags
    tags.ship_signature = ship_signature(list_data)
    frame.tags = tags
end

local function render_planets_page(frame, content)
    local leak_left = technology_decay.left_ticks()
    local header = content.add{
        type = 'flow',
        name = PLANET_HEADER_NAME,
        direction = 'horizontal',
    }
    header.style.vertical_align = 'center'
    header.add{
        type = 'label',
        name = TECH_LEAK_COUNTDOWN_NAME,
        caption = leak_left and {
            'un.tech-leak-countdown',
            format_countdown(leak_left),
        } or {'un.tech-leak-paused'},
        tooltip = {'un.tech-leak-tooltip'},
    }
    add_info_sprite(header, {'un.planet-page-note'})
    local list = content.add{
        type = 'table',
        name = PLANET_TABLE_NAME,
        column_count = 3,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.planet-column-name'}}
    list.add{type = 'label', caption = {'un.planet-column-countdown'}}
    list.add{type = 'label', caption = {'un.planet-column-traits'}}
    for _, item in ipairs(disasters.list()) do
        list.add{type = 'label', caption = planet_label(item.name)}
        list.add{type = 'label', name = planet_countdown_name(item.name)}
        local traits = list.add{
            type = 'flow',
            name = planet_traits_name(item.name),
            direction = 'vertical',
        }
        render_planet_traits(traits, item)
    end
    set_frame_state(frame, 'planets')
end

local function faction_element_name(kind, planet_name)
    return 'un_faction_' .. kind .. '_' .. planet_name
end

local function faction_statistics(planet_name, ship_list, property_counts)
    local force = factions.of_planet(planet_name)
    local online = 0
    local total = 0
    if force and force.valid then
        for _, member in pairs(force.players) do
            total = total + 1
            if member.connected then online = online + 1 end
        end
    end
    local ship_count = 0
    for _, item in ipairs(ship_list) do
        if item.record.force_name == (force and force.name) then
            ship_count = ship_count + 1
        end
    end
    return {
        online = online,
        total = total,
        properties = property_counts[planet_name] or 0,
        ships = ship_count,
    }
end

local function update_factions_page(player, content)
    local list = content[FACTION_TABLE_NAME]
    if not (list and list.valid) then return end
    local current = factions.of_player(player)
    local ship_list = ships.list()
    local property_counts = {}
    for _, property in ipairs(properties.list()) do
        local planet_name = property.sample_planet
        property_counts[planet_name] = (property_counts[planet_name] or 0) + 1
    end
    for _, planet_name in ipairs(config.public_planets) do
        local data = faction_statistics(planet_name, ship_list, property_counts)
        local status = list[faction_element_name('status', planet_name)]
        local population = list[faction_element_name('population', planet_name)]
        local property_count = list[faction_element_name('properties', planet_name)]
        local ship_count = list[faction_element_name('ships', planet_name)]
        local button = list[FACTION_SWITCH_PREFIX .. planet_name]
        local switch_cost = factions.switch_stamina_cost(planet_name)
        local online_ready = settings.online_requirement_met(
            player,
            'faction_switch_min_online_hours'
        )
        if status and status.valid then
            status.caption = current == planet_name
                and {'un.faction-current'}
                or factions.relation_caption(current, planet_name)
        end
        if population and population.valid then
            population.caption = {'un.faction-population', data.online, data.total}
        end
        if property_count and property_count.valid then
            property_count.caption = tostring(data.properties)
        end
        if ship_count and ship_count.valid then
            ship_count.caption = tostring(data.ships)
        end
        if button and button.valid then
            button.enabled = current ~= planet_name
                and online_ready
                and stamina.get(player.index) >= switch_cost
            if current == planet_name then
                button.tooltip = {'un.faction-already-current'}
            elseif not online_ready then
                button.tooltip = {
                    '',
                    online_requirement_caption(
                        player,
                        'faction_switch_min_online_hours',
                        'un.faction-online-required'
                    ),
                    '\n\n',
                    switch_cost == 0 and {
                        'un.faction-switch-tooltip-free',
                        planet_label(planet_name),
                        config.normal_respawn_seconds,
                    } or {
                        'un.faction-switch-tooltip',
                        planet_label(planet_name),
                        switch_cost,
                        config.normal_respawn_seconds,
                    },
                }
            else
                button.tooltip = switch_cost == 0 and {
                    'un.faction-switch-tooltip-free',
                    planet_label(planet_name),
                    config.normal_respawn_seconds,
                } or {
                    '',
                    {
                    'un.faction-switch-tooltip',
                    planet_label(planet_name),
                    switch_cost,
                    config.normal_respawn_seconds,
                    },
                    button.enabled and '' or {
                        '',
                        '\n',
                        {'un.suicide-stamina-insufficient'},
                    },
                }
            end
            if button.tags.action ~= 'faction-switch-confirm' then
                button.caption = current == planet_name
                    and {'un.faction-current'} or {'un.faction-switch'}
                button.tags = {
                    action = 'faction-switch',
                    planet = planet_name,
                }
            end
        end
    end
end

local function render_factions_page(player, frame, content)
    local current_planet = factions.of_player(player) or 'nauvis'
    local summary = content.add{
        type = 'flow',
        direction = 'horizontal',
    }
    summary.style.vertical_align = 'center'
    summary.add{
        type = 'label',
        caption = {
            'un.faction-current-summary',
            factions.display_name(current_planet),
        },
    }
    add_info_sprite(summary, {
        'un.faction-page-tooltip',
        config.suicide_stamina_cost,
        config.normal_respawn_seconds,
        config.faction_diplomacy_start_hours,
    })
    local list = content.add{
        type = 'table',
        name = FACTION_TABLE_NAME,
        column_count = 6,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.faction-column-name'}}
    list.add{type = 'label', caption = {'un.faction-column-relation'}}
    list.add{type = 'label', caption = {'un.faction-column-population'}}
    list.add{type = 'label', caption = {'un.faction-column-properties'}}
    list.add{type = 'label', caption = {'un.faction-column-ships'}}
    list.add{type = 'label', caption = {'un.faction-column-action'}}
    for _, planet_name in ipairs(config.public_planets) do
        list.add{type = 'label', caption = factions.display_name(planet_name)}
        list.add{type = 'label', name = faction_element_name('status', planet_name)}
        list.add{type = 'label', name = faction_element_name('population', planet_name)}
        list.add{type = 'label', name = faction_element_name('properties', planet_name)}
        list.add{type = 'label', name = faction_element_name('ships', planet_name)}
        list.add{
            type = 'button',
            name = FACTION_SWITCH_PREFIX .. planet_name,
            caption = {'un.faction-switch'},
            tags = {action = 'faction-switch', planet = planet_name},
        }
    end
    set_frame_state(frame, 'factions')
    update_factions_page(player, content)
end

crime_error_caption = function(err)
    if err == 'crime-online-time' then
        return {'un.crime-online-required-short'}
    end
    if err == 'in-space' then return {'un.crime-error-space'} end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'no-targets' then return {'un.crime-error-no-targets'} end
    if err == 'insufficient-credit' then
        return {'un.crime-error-credit', config.crime_coin_cost}
    end
    if err == 'insufficient-stamina' then
        return {'un.crime-error-stamina', config.crime_stamina_cost}
    end
    return {'un.crime-error-location'}
end

update_crime_action = function(player, content)
    local actions = content[CRIME_ACTIONS_NAME]
    local status = actions and actions.valid and actions[CRIME_STATUS_NAME]
    local button = actions and actions.valid and actions[CRIME_BUTTON_NAME]
    if not (status and status.valid and button and button.valid) then return end
    local available, err, planet_name, count = crime.availability(player)
    status.caption = available and {
        'un.crime-ready',
        planet_label(planet_name),
        count,
    } or err == 'crime-online-time' and online_requirement_caption(
        player,
        'crime_min_online_hours',
        'un.crime-online-required'
    ) or crime_error_caption(err)
    button.enabled = available
    local details = {
        'un.crime-button-tooltip',
        config.crime_coin_cost,
        config.crime_stamina_cost,
        config.crime_price_scale,
    }
    local unavailable = err == 'crime-online-time' and online_requirement_caption(
        player,
        'crime_min_online_hours',
        'un.crime-online-required'
    ) or crime_error_caption(err)
    button.tooltip = available and details or {
        '',
        unavailable,
        '\n\n',
        details,
    }
end

local function count_pairs(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local function render_admin_page(player, frame, content)
    if not player.admin then return end
    local scroll = content.add{type = 'scroll-pane', name = ADMIN_SCROLL_NAME}
    scroll.style.minimal_width = 760
    scroll.style.maximal_height = 620

    local summary = scroll.add{
        type = 'table',
        column_count = 2,
        style = 'bordered_table',
    }
    summary.add{type = 'label', caption = {'un.admin-summary-players'}}
    summary.add{type = 'label', caption = count_pairs(storage.players)}
    summary.add{type = 'label', caption = {'un.admin-summary-properties'}}
    summary.add{type = 'label', caption = #properties.list()}
    summary.add{type = 'label', caption = {'un.admin-summary-ships'}}
    summary.add{type = 'label', caption = #ships.list()}
    summary.add{type = 'label', caption = {'un.admin-summary-dropoffs'}}
    summary.add{type = 'label', caption = count_pairs(storage.dropoffs)}
    summary.add{type = 'label', caption = {'un.admin-summary-ledger'}}
    summary.add{type = 'label', caption = count_pairs(storage.ledger.records)}

    scroll.add{type = 'line'}
    scroll.add{type = 'label', caption = {'un.admin-settings-title'}, style = 'heading_2_label'}
    local setting_table = scroll.add{
        type = 'table',
        name = ADMIN_SETTINGS_TABLE_NAME,
        column_count = 3,
        style = 'bordered_table',
    }
    for _, spec in ipairs(ADMIN_NUMBER_SETTINGS) do
        local key = spec[1]
        setting_table.add{type = 'label', caption = {spec[2]}}
        local input = setting_table.add{
            type = 'textfield',
            name = admin_setting_input_name(key),
            text = tostring(settings.get(key)),
            numeric = true,
            allow_decimal = key == 'ship_life_hours'
                or key == 'faction_switch_min_online_hours'
                or key == 'crime_min_online_hours'
                or key == 'ship_build_min_online_hours'
                or key == 'deconstruction_min_online_hours'
                or key == 'cleanup_idle_hours'
                or key == 'planet_reset_min_hours'
                or key == 'planet_reset_max_hours'
                or key == 'planet_reset_exponent'
                or key == 'property_tax_percent'
                or key == 'property_price_factor'
                or key == 'technology_price_multiplier'
                or key == 'spoil_time_modifier'
                or key == 'asteroid_spawning_rate'
                or key == 'tech_leak_interval_hours'
                or key == 'tech_leak_max_percent'
                or key == 'property_build_price_multiplier'
                or key == 'property_salvage_percent'
                or key:match('^property_lifetime_') ~= nil
                or key:match('^property_decay_') ~= nil,
            allow_negative = false,
            lose_focus_on_confirm = true,
        }
        input.style.width = 150
        setting_table.add{
            type = 'button',
            caption = {'un.admin-apply'},
            tags = {action = 'admin-setting-apply', setting = key},
        }
    end

    local switches = scroll.add{type = 'flow', direction = 'vertical'}
    switches.style.vertical_align = 'center'
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-planet-resets'},
        switch_state = settings.get('planet_resets_enabled') and 'right' or 'left',
        allow_none_state = false,
        tags = {action = 'admin-setting-switch', setting = 'planet_resets_enabled'},
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-tech-leak-enabled'},
        switch_state = settings.get('tech_leak_enabled') and 'right' or 'left',
        allow_none_state = false,
        tags = {action = 'admin-setting-switch', setting = 'tech_leak_enabled'},
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-property-access'},
        switch_state = settings.get('admin_property_access') and 'right' or 'left',
        allow_none_state = false,
        tags = {action = 'admin-setting-switch', setting = 'admin_property_access'},
    }

    scroll.add{type = 'line'}
    scroll.add{type = 'label', caption = {'un.admin-properties-title'}, style = 'heading_2_label'}
    scroll.add{
        type = 'button',
        caption = {'un.admin-property-repair'},
        tags = {action = 'admin-property-repair'},
    }
    local property_table = scroll.add{
        type = 'table',
        name = ADMIN_PROPERTY_TABLE_NAME,
        column_count = 3,
        style = 'bordered_table',
    }
    property_table.add{type = 'label', caption = {'un.admin-property-id'}}
    property_table.add{type = 'label', caption = {'un.property-column-name'}}
    property_table.add{type = 'label', caption = {'un.property-column-lifetime'}}
    for _, property in ipairs(properties.list()) do
        property_table.add{type = 'label', caption = tostring(property.id)}
        property_table.add{type = 'label', caption = properties.surface_display_name(property)}
        property_table.add{
            type = 'label',
            caption = property_lifetime_caption(property),
        }
    end

    scroll.add{type = 'line'}
    scroll.add{type = 'label', caption = {'un.admin-balances-title'}, style = 'heading_2_label'}
    local player_table = scroll.add{
        type = 'table',
        name = ADMIN_PLAYER_TABLE_NAME,
        column_count = 3,
        style = 'bordered_table',
    }
    player_table.add{type = 'label', caption = {'un.player-column-name'}}
    player_table.add{type = 'label', caption = {'un.credit-label'}}
    player_table.add{type = 'label', caption = {'un.admin-operation'}}
    for _, listed_player in ipairs(sorted_players(player.index)) do
        player_table.add{type = 'label', caption = listed_player.name}
        local balance = player_table.add{
            type = 'textfield',
            name = admin_balance_input_name(listed_player.index),
            text = tostring(economy.get_balance(listed_player.index)),
            numeric = true,
            allow_decimal = false,
            allow_negative = false,
        }
        balance.style.width = 150
        player_table.add{
            type = 'button',
            caption = {'un.admin-set-balance'},
            tags = {action = 'admin-balance-set', target_index = listed_player.index},
        }
    end
    set_frame_state(frame, 'admin')
end

local function add_help_line(parent, caption, heading)
    local label = parent.add{type = 'label', caption = caption}
    label.style.single_line = false
    label.style.maximal_width = 640
    label.style.bottom_margin = 10
    if heading then label.style.font = 'default-bold' end
    return label
end

local function add_help_card(parent, title)
    local card = parent.add{type = 'frame', direction = 'vertical'}
    card.style.horizontally_stretchable = true
    card.style.padding = 12
    local heading = card.add{type = 'label', caption = title}
    heading.style.font = 'default-large-bold'
    heading.style.bottom_margin = 6
    return card
end

local function add_help_gap(parent)
    local gap = parent.add{type = 'empty-widget'}
    gap.style.height = 8
end

local function render_help_page(player, frame, content, mode)
    mode = mode or 'brief'
    if mode == 'admin' and not player.admin then mode = 'brief' end
    local title = content.add{
        type = 'label',
        caption = mode == 'story' and {'un.help-story-title'}
            or mode == 'admin' and {'un.help-admin-title'}
            or mode == 'full' and {'un.help-full-title'}
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
    local story = modes.add{
        type = 'button',
        name = HELP_STORY_NAME,
        caption = {'un.help-mode-story'},
    }
    local admin
    if player.admin then
        admin = modes.add{
            type = 'button',
            name = HELP_ADMIN_NAME,
            caption = {'un.help-mode-admin'},
        }
    end
    story.enabled = mode ~= 'story'
    brief.enabled = mode ~= 'brief'
    advanced.enabled = mode ~= 'advanced'
    full.enabled = mode ~= 'full'
    if admin then admin.enabled = mode ~= 'admin' end

    local details = content.add{
        type = 'scroll-pane',
        name = HELP_DETAILS_NAME,
    }
    details.style.minimal_width = 740
    details.style.maximal_height = 620

    if mode == 'brief' or mode == 'advanced' or mode == 'full' then
        local intro = details.add{
            type = 'label',
            caption = {'un.help-layer-' .. mode},
        }
        intro.style.single_line = false
        intro.style.maximal_width = 700
        intro.style.font_color = {0.72, 0.72, 0.72}
        add_help_gap(details)
    end

    if mode == 'story' then
        local background = add_help_card(details, {'un.help-card-story'})
        add_help_line(background, {'un.help-story-background'})
        add_help_gap(details)
        local forces = add_help_card(details, {'un.help-card-factions'})
        add_help_line(forces, {
            'un.help-story-factions',
            config.suicide_stamina_cost,
            config.faction_diplomacy_start_hours,
        })
    elseif mode == 'brief' then
        local income = add_help_card(details, {'un.help-card-income'})
        add_help_line(income, {
            'un.help-brief-start',
            settings.get('deconstruction_min_online_hours'),
        })
        add_help_gap(details)
        local property = add_help_card(details, {'un.help-card-property'})
        add_help_line(property, {
            'un.help-brief-property',
            config.property_build_experience_per_point,
            config.property_build_base_lifetime_hours,
            config.property_build_stamina_cost,
            config.stamina_max,
        })
        add_help_gap(details)
        local travel = add_help_card(details, {'un.help-card-travel'})
        add_help_line(travel, {'un.help-brief-travel'})
        add_help_gap(details)
        local project = add_help_card(details, {'un.help-card-project'})
        add_help_line(project, {'un.help-brief-project'})
    elseif mode == 'advanced' then
        local beginner = add_help_card(details, {'un.help-section-beginner'})
        add_help_line(beginner, {'un.help-detail-linked-chest'})
        add_help_line(beginner, {
            'un.help-detail-science',
            config.science_conversion_ticks / config.ticks_per_minute,
        })
        add_help_gap(details)

        local property = add_help_card(details, {'un.help-detail-property-heading'})
        add_help_line(property, {
            'un.help-detail-property-build',
            config.property_build_experience_per_point,
            config.property_build_base_lifetime_hours,
            settings.get('property_lifetime_1_hours'),
            settings.get('property_lifetime_2_hours'),
            settings.get('property_lifetime_3_hours'),
            settings.get('property_decay_1_hours'),
            settings.get('property_decay_2_hours'),
            settings.get('property_decay_3_hours'),
            settings.get('property_build_price_multiplier'),
            config.property_price_cap,
            settings.get('property_limit_per_planet'),
            config.property_build_stamina_cost,
        })
        add_help_line(property, {'un.help-detail-property-basic'})
        add_help_gap(details)

        local travel = add_help_card(details, {'un.help-detail-ship-heading'})
        add_help_line(travel, {
            'un.help-detail-travel',
            config.fast_respawn_stamina_cost,
            config.fast_respawn_seconds,
            config.normal_respawn_seconds,
        })
        add_help_gap(details)

        local world = add_help_card(details, {'un.help-detail-world-heading'})
        add_help_line(world, {'un.help-detail-resets'})
        add_help_line(world, {
            'un.help-detail-tech-leak',
            settings.get('tech_leak_interval_hours'),
        })
    elseif mode == 'full' then
        local growth = add_help_card(details, {
            'un.help-detail-growth-heading',
        })
        add_help_line(growth, {
            'un.help-detail-experience-effects',
            config.ship_base_width,
            config.ship_width_per_level,
            settings.get('ship_life_hours'),
            settings.get('property_tax_percent'),
        })
        add_help_gap(details)

        local formulas = add_help_card(details, {
            'un.help-detail-formulas-heading',
        })
        add_help_line(formulas, {
            'un.help-detail-property-price',
            config.property_price_cap,
            settings.get('property_price_factor'),
        })
        add_help_line(formulas, {
            'un.help-detail-property-trade',
            settings.get('property_tax_percent'),
            settings.get('property_salvage_percent'),
        })
        add_help_gap(details)

        local world = add_help_card(details, {'un.help-detail-world-heading'})
        add_help_line(world, {
            'un.help-detail-world-randomization',
            config.public_planet_resource_base.frequency,
            config.public_planet_resource_base.size,
            config.public_planet_resource_base.richness,
            config.public_planet_resource_spread,
            config.public_planet_terrain_spread,
            config.public_planet_cliff_spread,
            config.public_planet_enemy_spread,
            config.public_planet_peaceful_chance * 100,
            settings.get('technology_price_multiplier'),
            settings.get('spoil_time_modifier'),
            settings.get('asteroid_spawning_rate'),
        })
        add_help_line(world, {
            'un.help-detail-reset-schedule',
            settings.get('planet_reset_min_hours'),
            settings.get('planet_reset_max_hours'),
            settings.get('planet_reset_exponent'),
        })
        add_help_line(world, {
            'un.help-detail-tech-leak-formula',
            settings.get('tech_leak_max_percent'),
        })
    else
        local security = add_help_card(details, {
            'un.help-admin-security-heading',
        })
        add_help_line(security, {'un.help-admin-security'})
        add_help_gap(details)

        local limits = add_help_card(details, {
            'un.help-admin-limits-heading',
        })
        add_help_line(limits, {
            'un.help-admin-limits',
            settings.get('property_limit_per_planet'),
            settings.get('cleanup_idle_hours'),
        })
        add_help_gap(details)

        local controls = add_help_card(details, {
            'un.help-admin-controls-heading',
        })
        add_help_line(controls, {'un.help-admin-controls'})
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

local function list_refresh_due(frame, page)
    local bucket = math.floor(game.tick / config.gui_list_refresh_ticks)
    local key = 'list_refresh_' .. page
    if frame.tags[key] == bucket then return false end
    local tags = frame.tags
    tags[key] = bucket
    frame.tags = tags
    return true
end

local function player_faction_icon(player)
    local planet_name = factions.of_player(player)
    if not planet_name then return {'un.faction-unknown'} end
    return {'', '[img=space-location/' .. planet_name .. ']'}
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
    add_info_sprite(actions, {
        'un.player-social-tooltip',
        settings.get('friend_limit'),
        config.transfer_min_amount,
        config.transfer_fee_rate * 100,
        config.transfer_min_fee,
    })
    local scroll = add_list_scroll(content, PLAYER_SCROLL_NAME)
    local list = scroll.add{
        type = 'table',
        name = PLAYER_TABLE_NAME,
        column_count = 9,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.player-column-status'}}
    list.add{type = 'label', caption = {'un.player-column-name'}}
    list.add{type = 'label', caption = {'un.player-column-faction'}}
    list.add{type = 'label', caption = {'un.player-column-online-hours'}}
    list.add{type = 'label', caption = {'un.player-column-offline-hours'}}
    list.add{type = 'label', caption = {'un.player-column-locale'}}
    list.add{type = 'label', caption = {'un.player-column-coins'}}
    list.add{type = 'label', caption = {'un.player-column-total-level'}}
    list.add{type = 'label', caption = {'un.player-column-friend'}}

    for _, player in ipairs(sorted_players(viewer.index)) do
        list.add{type = 'label', name = player_element_name('status', player.index)}
        list.add{type = 'label', caption = player.name}
        list.add{
            type = 'label',
            name = player_element_name('faction', player.index),
            caption = player_faction_icon(player),
            tooltip = factions.display_name(factions.of_player(player)),
        }
        list.add{type = 'label', name = player_element_name('online', player.index)}
        list.add{type = 'label', name = player_element_name('offline', player.index)}
        list.add{type = 'label', name = player_element_name('locale', player.index)}
        list.add{type = 'label', name = player_element_name('coins', player.index)}
        list.add{type = 'label', name = player_element_name('level', player.index)}
        if player.index == viewer.index then
            list.add{type = 'label', caption = {'un.player-self'}}
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
    if page == 'admin' and not player.admin then page = 'help' end
    content.clear()

    if page == 'help' then
        render_help_page(player, frame, content)
    elseif page == 'overview' then
        render_overview_page(player, frame, content)
    elseif page == 'property-build' then
        render_property_build_page(player, frame, content)
    elseif page == 'property' then
        render_property_table(player, frame, content)
    elseif page == 'planets' then
        render_planets_page(frame, content)
    elseif page == 'ships' then
        render_ships_page(player, frame, content)
    elseif page == 'players' then
        render_players_page(player, frame, content)
    elseif page == 'factions' then
        render_factions_page(player, frame, content)
    elseif page == 'admin' then
        render_admin_page(player, frame, content)
    else
        page = 'help'
        render_help_page(player, frame, content)
    end

    local navigation = frame[NAVIGATION_NAME]
    navigation[NAV_HELP_NAME].enabled = page ~= 'help'
    navigation[NAV_UBI_NAME].enabled = page ~= 'overview'
    navigation[NAV_PROPERTY_BUILD_NAME].enabled = page ~= 'property-build'
    navigation[NAV_PROPERTY_NAME].enabled = page ~= 'property'
    navigation[NAV_PLANETS_NAME].enabled = page ~= 'planets'
    navigation[NAV_SHIPS_NAME].enabled = page ~= 'ships'
    navigation[NAV_PLAYERS_NAME].enabled = page ~= 'players'
    navigation[NAV_FACTIONS_NAME].enabled = page ~= 'factions'
    local admin = navigation[NAV_ADMIN_NAME]
    if admin and admin.valid then admin.enabled = page ~= 'admin' end
end

local function property_error(err)
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'price-increased' then return {'un.property-error-price-changed'} end
    if err == 'not-owner' or err == 'already-owner' then
        return {'un.property-error-ownership'}
    end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'travel-restricted' then return {'un.travel-restricted'} end
    if err == 'planet-closed' then return {'un.travel-planet-closed'} end
    if err == 'wrong-faction' then return {'un.property-error-wrong-faction'} end
    if err == 'ship-invalid-planet' then return {'un.ship-invalid-planet'} end
    if err == 'ship-already-have' then return {'un.ship-already-have'} end
    if err == 'ship-missing' then return {'un.ship-missing'} end
    if err == 'ship-not-ready' then return {'un.ship-not-ready'} end
    if err == 'ship-create-failed' then return {'un.ship-create-failed'} end
    if err == 'ship-online-time' then return {'un.ship-online-required-short'} end
    if err == 'insufficient-experience' then
        return {'un.property-build-insufficient-experience'}
    end
    if err == 'invalid-build-option' then
        return {'un.property-build-invalid'}
    end
    if err == 'insufficient-stamina' then return {'un.stamina-insufficient'} end
    if err == 'property-limit' then return {'un.property-build-limit'} end
    if err == 'invalid-property-name' then
        return {
            'un.property-build-name-invalid',
            config.property_name_max_characters,
        }
    end
    if err == 'salvage-value-changed' then
        return {'un.property-salvage-value-changed'}
    end
    if err == 'not-player-built' or err == 'permanent' then
        return {'un.property-salvage-unavailable'}
    end
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
    local remaining = property_table[property_remaining_name(property.id)]
    if remaining and remaining.valid then
        remaining.caption = property_lifetime_caption(property)
    end
    local price = property_table[property_price_name(property.id)]
    local current_price = properties.current_price(property)
    if price and price.valid then
        price.caption = {'un.coin-amount',
            format_integer(current_price)}
    end
    local change = property_table[property_price_change_name(property.id)]
    if change and change.valid then
        change.caption = property_price_change_caption(property, current_price)
    end

    local can_buy, buy_error = properties.buy_availability(player, property)
    local buy = property_table[property_buy_name(property.id)]
    if buy and buy.valid then
        buy.enabled = can_buy
        buy.tooltip = can_buy and {'un.property-buy'}
            or disabled_tooltip('buy', buy_error)
        if buy.tags.action ~= 'property-confirm-buy' then
            buy.caption = {'un.property-buy'}
            buy.tags = {
                action = 'property-buy',
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

local function update_ship_actions(player, content)
    local platform, record = ships.of(player.index)
    local status = content[SHIP_STATUS_NAME]
    local ship_actions = content[SHIP_ACTIONS_NAME]
    if not (status and status.valid and ship_actions and ship_actions.valid) then
        return
    end
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
        local online_ready = settings.online_requirement_met(
            player,
            'ship_build_min_online_hours'
        )
        create.enabled = online_ready
            and stamina.get(player.index) >= config.ship_stamina_cost
        local unavailable = not online_ready and online_requirement_caption(
            player,
            'ship_build_min_online_hours',
            'un.ship-online-required'
        ) or {'un.stamina-insufficient'}
        create.tooltip = create.enabled and ship_create_tooltip() or {
            '',
            unavailable,
            '\n\n',
            ship_create_tooltip(),
        }
        scuttle.enabled = false
    end
end

local function update_frame(player)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then return end
    local content = frame[CONTENT_NAME]
    if not (content and content.valid) then return end
    local page = frame.tags.page or 'overview'

    if page == 'admin' and not player.admin then
        render_page(player, 'help')
        return
    end

    if page == 'overview' then
        local balance_table = content[BALANCE_TABLE_NAME]
        local balance = balance_table and balance_table.valid
            and balance_table[BALANCE_NAME]
        if balance and balance.valid then
            balance.caption = format_integer(economy.get_balance(player.index))
        end
        local stamina_label = balance_table and balance_table.valid
            and balance_table[STAMINA_NAME]
        if stamina_label and stamina_label.valid then
            stamina_label.caption = {
                'un.stamina-amount',
                format_integer(stamina.get(player.index)),
                format_integer(config.stamina_max),
            }
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
        local kit = content[STARTER_KIT_NAME]
        if kit and kit.valid then
            local can_buy, buy_error = starter.can_buy(player)
            kit.enabled = can_buy
            local kit_details = {'un.starter-kit-tooltip'}
            kit.tooltip = can_buy and kit_details or {
                '',
                buy_error == 'insufficient-stamina'
                    and {'un.starter-kit-insufficient'}
                    or {'un.starter-kit-unavailable'},
                '\n\n',
                kit_details,
            }
            if kit.tags.action ~= 'starter-kit-confirm' then
                kit.caption = {
                    'un.starter-kit-buy',
                    config.starter_kit_equipment[2].count,
                    config.starter_kit_items[1].count,
                    config.starter_kit_stamina_cost,
                }
                kit.tags = {action = 'starter-kit-buy'}
            end
        end
        local wood = content[WOOD_SUPPLY_NAME]
        if wood and wood.valid then
            local can_buy, buy_error = starter.can_buy_wood(player)
            wood.enabled = can_buy
            local wood_details = {
                'un.wood-supply-tooltip',
                config.wood_supply_count,
                config.wood_supply_stamina_cost,
            }
            wood.tooltip = can_buy and wood_details or {
                '',
                buy_error == 'insufficient-stamina'
                    and {'un.wood-supply-insufficient-stamina'}
                    or {'un.wood-supply-unavailable'},
                '\n\n',
                wood_details,
            }
            if wood.tags.action ~= 'wood-supply-confirm' then
                wood.caption = {
                    'un.wood-supply-buy',
                    config.wood_supply_count,
                    config.wood_supply_stamina_cost,
                }
                wood.tags = {action = 'wood-supply-buy'}
            end
        end
        if list_refresh_due(frame, 'experience') then
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
        end
    elseif page == 'property-build' then
        update_property_build_page(player, content)
    elseif page == 'planets' then
        local planet_header = content[PLANET_HEADER_NAME]
        local leak = planet_header and planet_header.valid
            and planet_header[TECH_LEAK_COUNTDOWN_NAME]
        if leak and leak.valid then
            local leak_left = technology_decay.left_ticks()
            leak.caption = leak_left and {
                'un.tech-leak-countdown',
                format_countdown(leak_left),
            } or {'un.tech-leak-paused'}
        end
        local list = content[PLANET_TABLE_NAME]
        if list and list.valid then
            for _, item in ipairs(disasters.list()) do
                local countdown = list[planet_countdown_name(item.name)]
                if countdown and countdown.valid then
                    countdown.caption = item.paused
                        and {'un.planet-countdown-paused',
                            format_countdown(item.left_ticks)}
                        or item.left_ticks
                        and format_countdown(item.left_ticks)
                        or {'un.planet-countdown-rebuilding'}
                end
                local traits = list[planet_traits_name(item.name)]
                if traits and traits.valid then
                    render_planet_traits(traits, item)
                end
            end
        end
    elseif page == 'ships' then
        if list_refresh_due(frame, 'ships') then
            local list_data = ships.list()
            local signature = ship_signature(list_data)
            if frame.tags.ship_signature ~= signature then
                content.clear()
                render_ships_page(player, frame, content)
            else
                update_ship_actions(player, content)
                local list = table_in_scroll(
                    content,
                    SHIP_SCROLL_NAME,
                    SHIP_TABLE_NAME
                )
                if list and list.valid then
                    for _, item in ipairs(list_data) do
                        local remaining = list[ship_remaining_name(item.index)]
                        if remaining and remaining.valid then
                            local hours = math.ceil(
                                math.max(0, ships.left_ticks(item.record))
                                    / config.ticks_per_hour
                            )
                            remaining.caption = {'un.ship-remaining-hours', hours}
                        end
                    end
                end
            end
        end
    elseif page == 'property' then
        update_property_hospice_action(player, content)
        update_property_salvage_action(player, content)
        local sort_field = property_sort_state(frame)
        local sort_bucket = math.floor(game.tick / config.ticks_per_minute)
        local price_sort_changed = (sort_field == 'price'
                or sort_field == 'change')
            and frame.tags.property_sort_bucket ~= sort_bucket
        local refresh_rows = list_refresh_due(frame, 'property')
        if (frame.tags.property_revision or -1)
                ~= (storage.property_revision or 0) or price_sort_changed then
            render_property_table(player, frame, content)
        elseif refresh_rows then
            local property_table = table_in_scroll(
                content,
                PROPERTY_SCROLL_NAME,
                PROPERTY_TABLE_NAME
            )
            if property_table and property_table.valid then
                for _, property in ipairs(properties.list(
                    factions.of_player(player)
                )) do
                    update_property_row(player, property_table, property)
                end
            end
            update_crime_action(player, content)
        end
    elseif page == 'factions' then
        if list_refresh_due(frame, 'factions') then
            update_factions_page(player, content)
        end
    elseif page == 'players' then
        if list_refresh_due(frame, 'players') then
            if frame.tags.player_signature ~= player_signature() then
                content.clear()
                render_players_page(player, frame, content)
            end
            local list = table_in_scroll(
                content,
                PLAYER_SCROLL_NAME,
                PLAYER_TABLE_NAME
            )
            if list and list.valid then
                for _, listed_player in pairs(game.players) do
                    local status = list[player_element_name('status', listed_player.index)]
                    local faction = list[player_element_name('faction', listed_player.index)]
                    local online = list[player_element_name('online', listed_player.index)]
                    local offline = list[player_element_name('offline', listed_player.index)]
                    local locale = list[player_element_name('locale', listed_player.index)]
                    local coins = list[player_element_name('coins', listed_player.index)]
                    local level = list[player_element_name('level', listed_player.index)]
                    if status and status.valid then
                        status.caption = listed_player.connected
                            and {'un.player-online'} or {'un.player-offline'}
                    end
                    if faction and faction.valid then
                        local planet_name = factions.of_player(listed_player)
                        faction.caption = player_faction_icon(listed_player)
                        faction.tooltip = factions.display_name(planet_name)
                    end
                    if online and online.valid then
                        online.caption = format_hours(playtime.ticks(listed_player))
                    end
                    if offline and offline.valid then
                        local account = economy.ensure_account(listed_player.index)
                        local observed_ticks = math.max(
                            0,
                            game.tick - (account.created_tick or game.tick)
                        )
                        local offline_ticks = math.max(
                            0,
                            observed_ticks - playtime.ticks(listed_player)
                        )
                        offline.caption = format_hours(offline_ticks)
                    end
                    if locale and locale.valid then
                        locale.caption = listed_player.locale
                    end
                    if coins and coins.valid then
                        coins.caption = format_integer(
                            economy.get_balance(listed_player.index)
                        )
                    end
                    if level and level.valid then
                        level.caption = format_integer(
                            experience.total_level(listed_player.index)
                        )
                    end
                end
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
    navigation.add{
        type = 'button',
        name = NAV_FACTIONS_NAME,
        caption = {'un.page-factions'},
    }
    navigation.add{type = 'button', name = NAV_PLANETS_NAME, caption = {'un.page-planets'}}
    navigation.add{type = 'button', name = NAV_PROPERTY_NAME, caption = {'un.page-property'}}
    navigation.add{
        type = 'button',
        name = NAV_PROPERTY_BUILD_NAME,
        caption = {'un.page-property-build'},
    }
    navigation.add{type = 'button', name = NAV_SHIPS_NAME, caption = {'un.page-ships'}}
    navigation.add{type = 'button', name = NAV_PLAYERS_NAME, caption = {'un.page-players'}}
    if player.admin then
        navigation.add{type = 'button', name = NAV_ADMIN_NAME, caption = {'un.page-admin'}}
    end

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
events.on(defines.events.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index)
    if player then update_home_button(player) end
end)

local function rebuild_for_admin_change(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then return end
    local page = frame.tags.page or 'help'
    if page == 'admin' and not player.admin then page = 'help' end
    open_frame(player, page)
end

events.on(defines.events.on_player_promoted, rebuild_for_admin_change)
events.on(defines.events.on_player_demoted, rebuild_for_admin_change)

events.on(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if element.name == HUD_MENU_NAME then
        open_frame(player, 'help')
    elseif element.name == HUD_LAST_PROPERTY_NAME then
        local ok, err = properties.home_travel(player)
        if not ok then player.print(property_error(err)) end
    elseif element.name == CLOSE_NAME then
        close_frame(player)
    elseif element.name == NAV_HELP_NAME then
        render_page(player, 'help')
        update_frame(player)
    elseif element.name == HELP_BRIEF_NAME
            or element.name == HELP_ADVANCED_NAME
            or element.name == HELP_FULL_NAME
            or element.name == HELP_ADMIN_NAME
            or element.name == HELP_STORY_NAME then
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if not (content and content.valid) then return end
        local mode = element.name == HELP_STORY_NAME and 'story'
            or element.name == HELP_ADMIN_NAME and 'admin'
            or element.name == HELP_FULL_NAME and 'full'
            or element.name == HELP_ADVANCED_NAME and 'advanced' or 'brief'
        content.clear()
        render_help_page(player, frame, content, mode)
        update_frame(player)
    elseif element.name == NAV_UBI_NAME then
        render_page(player, 'overview')
        update_frame(player)
    elseif element.name == NAV_PROPERTY_BUILD_NAME then
        render_page(player, 'property-build')
        update_frame(player)
    elseif element.name == NAV_PROPERTY_NAME then
        render_page(player, 'property')
        update_frame(player)
    elseif element.name == NAV_PLANETS_NAME then
        render_page(player, 'planets')
        update_frame(player)
    elseif element.name == NAV_SHIPS_NAME then
        render_page(player, 'ships')
        update_frame(player)
    elseif element.name == NAV_PLAYERS_NAME then
        render_page(player, 'players')
        update_frame(player)
    elseif element.name == NAV_FACTIONS_NAME then
        render_page(player, 'factions')
        update_frame(player)
    elseif element.name == NAV_ADMIN_NAME then
        if player.admin then
            render_page(player, 'admin')
            update_frame(player)
        end
    elseif element.name == UBI_CLAIM_NAME then
        economy.claim_ubi(player.index)
        update_frame(player)
    elseif element.name == STARTER_KIT_NAME then
        if element.tags.action == 'starter-kit-confirm' then
            local ok, err = starter.buy(player)
            if ok then
                player.print({'un.starter-kit-purchased'})
            elseif err == 'insufficient-stamina' then
                player.print({'un.starter-kit-insufficient'})
            else
                player.print({'un.starter-kit-unavailable'})
            end
            render_page(player, 'overview')
            update_frame(player)
        else
            element.caption = {
                'un.starter-kit-confirm',
                config.starter_kit_stamina_cost,
            }
            element.tags = {action = 'starter-kit-confirm'}
        end
    elseif element.name == WOOD_SUPPLY_NAME then
        if element.tags.action == 'wood-supply-confirm' then
            local ok, err = starter.buy_wood(player)
            player.print(ok and {
                'un.wood-supply-purchased',
                config.wood_supply_count,
            } or err == 'insufficient-stamina'
                and {'un.wood-supply-insufficient-stamina'}
                or {'un.wood-supply-unavailable'})
            render_page(player, 'overview')
            update_frame(player)
        else
            element.caption = {
                'un.wood-supply-confirm',
                config.wood_supply_count,
                config.wood_supply_stamina_cost,
            }
            element.tags = {action = 'wood-supply-confirm'}
        end
    elseif element.name == SHIP_CREATE_NAME then
        local planet_name = factions.of_player(player)
        local platform, err = ships.create(player, planet_name)
        if not platform then player.print(property_error(err)) end
        render_page(player, 'ships')
        update_frame(player)
    elseif element.name == SHIP_SCUTTLE_NAME then
        if element.tags.action == 'ship-scuttle-confirm' then
            local ok, err = ships.scuttle(player)
            if not ok then player.print(property_error(err)) end
            render_page(player, 'ships')
            update_frame(player)
        else
            element.caption = {'un.ship-scuttle-confirm'}
            element.tags = {action = 'ship-scuttle-confirm'}
        end
    elseif element.name == CRIME_BUTTON_NAME then
        local attempted, result = crime.attempt(player)
        if not attempted then
            player.print(crime_error_caption(result))
            update_frame(player)
        elseif result then
            close_frame(player)
        else
            update_frame(player)
        end
    elseif element.name == PROPERTY_HOSPICE_BUTTON_NAME then
        local ok, err = properties.travel_to_hospice(player)
        if ok then
            close_frame(player)
        else
            player.print(property_error(err))
            update_frame(player)
        end
    elseif element.name:sub(1, #FACTION_SWITCH_PREFIX)
            == FACTION_SWITCH_PREFIX then
        local planet_name = element.tags.planet
        local switch_cost = factions.switch_stamina_cost(planet_name)
        if element.tags.action == 'faction-switch-confirm' then
            local ok, err = factions.switch_by_suicide(player, planet_name)
            if ok then
                close_frame(player)
            else
                player.print(err == 'insufficient-stamina'
                    and {'un.suicide-stamina-insufficient'}
                    or err == 'faction-online-time'
                    and online_requirement_caption(
                        player,
                        'faction_switch_min_online_hours',
                        'un.faction-online-required'
                    )
                    or err == 'same-faction' and {'un.faction-already-current'}
                    or {'un.suicide-unavailable'})
            end
        else
            element.caption = switch_cost == 0 and {
                'un.faction-switch-confirm-free',
                planet_label(planet_name),
            } or {
                'un.faction-switch-confirm',
                planet_label(planet_name),
                switch_cost,
            }
            element.tooltip = {
                '',
                switch_cost == 0 and {
                    'un.faction-switch-confirm-free',
                    planet_label(planet_name),
                } or {
                    'un.faction-switch-confirm',
                    planet_label(planet_name),
                    switch_cost,
                },
                '\n',
                switch_cost == 0 and {
                    'un.faction-switch-tooltip-free',
                    planet_label(planet_name),
                    config.normal_respawn_seconds,
                } or {
                    'un.faction-switch-tooltip',
                    planet_label(planet_name),
                    switch_cost,
                    config.normal_respawn_seconds,
                },
            }
            element.tags = {
                action = 'faction-switch-confirm',
                planet = planet_name,
            }
        end
    else
        local tags = element.tags
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if not (content and content.valid) then return end
        if tags.action == 'property-sort-column' then
            if not PROPERTY_SORT_FIELDS[tags.field] then return end
            local frame_tags = frame.tags
            if frame_tags.property_sort_field == tags.field then
                frame_tags.property_sort_descending
                    = frame_tags.property_sort_descending ~= true
            else
                frame_tags.property_sort_field = tags.field
                frame_tags.property_sort_descending = false
            end
            frame.tags = frame_tags
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action and tags.action:match('^admin%-') then
            if not player.admin then
                player.print({'un.admin-only'})
                render_page(player, 'help')
                return
            end
            if tags.action == 'admin-setting-apply' then
                local input = element.parent[admin_setting_input_name(tags.setting)]
                local ok = input and input.valid
                    and settings.set(tags.setting, input.text)
                if ok and tags.setting == 'property_tax_percent' then
                    properties.admin_set_tax(player, settings.get(tags.setting))
                end
                if ok and (tags.setting == 'technology_price_multiplier'
                        or tags.setting == 'spoil_time_modifier'
                        or tags.setting == 'asteroid_spawning_rate') then
                    disasters.apply_global_settings()
                end
                if ok and tags.setting == 'tech_leak_interval_hours' then
                    technology_decay.reschedule()
                end
                if ok and tags.setting == 'deconstruction_min_online_hours' then
                    permissions.refresh_connected(true)
                end
                player.print(ok and {'un.admin-setting-saved'}
                    or {'un.admin-invalid-value'})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-property-repair' then
                local ok, count = properties.admin_repair(player)
                player.print(ok and {'un.property-repaired', count}
                    or {'un.admin-operation-failed'})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-balance-set' then
                local input = element.parent[
                    admin_balance_input_name(tags.target_index)
                ]
                local ok = input and input.valid and economy.admin_set_balance(
                    player.index,
                    tags.target_index,
                    input.text
                )
                player.print(ok and {'un.admin-balance-saved'}
                    or {'un.admin-invalid-value'})
                render_page(player, 'admin')
                update_frame(player)
            end
        elseif tags.action == 'property-build' then
            local form = content[PROPERTY_BUILD_FORM_NAME]
            if not (form and form.valid) then return end
            local planet_name = property_build_planet(player)
            local lifetime_index = form[PROPERTY_BUILD_LIFETIME_NAME].selected_index
            local size_index = form[PROPERTY_BUILD_SIZE_NAME].selected_index
            local name_field = form[PROPERTY_BUILD_NAME_NAME]
            local custom_name, name_err = properties.normalize_build_name(
                name_field and name_field.valid and name_field.text or ''
            )
            if name_err then
                player.print(property_error(name_err))
                return
            end
            local can_build, err, requirement = properties.build_availability(
                player,
                planet_name,
                lifetime_index,
                size_index
            )
            if not can_build then
                player.print(property_error(err))
                update_property_build_page(player, content)
                return
            end
            element.caption = {
                'un.property-build-confirm',
                format_integer(requirement.experience_cost),
                format_integer(requirement.stamina_cost),
            }
            element.tags = {
                action = 'property-build-confirm',
                planet_name = planet_name,
                lifetime_index = lifetime_index,
                size_index = size_index,
                custom_name = custom_name or '',
            }
        elseif tags.action == 'property-build-confirm' then
            local property, err = properties.build(
                player,
                tags.planet_name,
                tags.lifetime_index,
                tags.size_index,
                tags.custom_name
            )
            player.print(property and {'un.property-built', property.id}
                or property_error(err))
            render_page(player, 'property-build')
            update_frame(player)
        elseif tags.action == 'property-salvage' then
            local property = properties.get(tags.property_id)
            local can_salvage, err, value
                = properties.salvage_availability(player, property)
            if not can_salvage then
                if not property_disappeared(err) then
                    player.print(property_error(err))
                end
                render_property_table(player, frame, content)
                update_frame(player)
                return
            end
            element.caption = {
                'un.property-salvage-confirm',
                format_integer(value),
            }
            element.tooltip = {
                'un.property-salvage-confirm-tooltip',
                format_integer(value),
            }
            element.tags = {
                action = 'property-confirm-salvage',
                property_id = property.id,
                quoted_value = value,
            }
        elseif tags.action == 'property-buy' then
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
                player.print({'un.friend-limit', settings.get('friend_limit')})
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
        elseif tags.action == 'property-confirm-salvage' then
            local ok, err = properties.salvage(
                player,
                tags.property_id,
                tags.quoted_value
            )
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

events.on(defines.events.on_gui_selection_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[FRAME_NAME]
    local content = frame and frame.valid and frame[CONTENT_NAME]
    if element.name ~= PROPERTY_BUILD_LIFETIME_NAME
            and element.name ~= PROPERTY_BUILD_SIZE_NAME then
        return
    end
    local form = content and content.valid and content[PROPERTY_BUILD_FORM_NAME]
    local button = form and form.valid and form[PROPERTY_BUILD_BUTTON_NAME]
    if not (player and button and button.valid) then return end
    button.tags = {action = 'property-build'}
    update_property_build_page(player, content)
end)

events.on(defines.events.on_gui_switch_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local tags = element.tags
    if tags.action == 'admin-setting-switch' then
        if not player.admin then
            player.print({'un.admin-only'})
            return
        end
        local enabled = element.switch_state == 'right'
        local ok = settings.set(tags.setting, enabled)
        if ok and tags.setting == 'planet_resets_enabled' then
            disasters.apply_enabled(enabled)
        end
        if ok and tags.setting == 'tech_leak_enabled' then
            technology_decay.apply_enabled(enabled)
        end
        player.print(ok and {'un.admin-setting-saved'}
            or {'un.admin-invalid-value'})
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then
            render_page(player, 'admin')
            update_frame(player)
        end
        return
    end
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
    local player = game.get_player(player_index)
    if player and player.valid then update_frame(player) end
end)

-- Derive open-window state from the synchronized GUI tree. A mutable module-local
-- cache would be empty on a joining peer but populated on the running server.
scheduler.every(config.gui_refresh_ticks, function()
    for _, player in pairs(game.connected_players) do
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then
            update_frame(player)
        end
    end
end)

return M
