local config = require('config')
local crime = require('scripts.crime')
local disasters = require('scripts.disasters')
local economy = require('scripts.economy')
local events = require('scripts.events')
local experience = require('scripts.experience')
local factions = require('scripts.factions')
local linked_inventory = require('scripts.linked_inventory')
local permissions = require('scripts.permissions')
local playtime = require('scripts.playtime')
local properties = require('scripts.properties')
local market = require('scripts.market')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local ships = require('scripts.ships')
local social = require('scripts.social')
local stamina = require('scripts.stamina')
local starter = require('scripts.starter')
local surfaces = require('scripts.surfaces')
local technology_decay = require('scripts.technology_decay')

local M = {}
M.market_gui = require('scripts.market_gui')
M.hud_travel = require('scripts.hud_travel')

local HUD_FLOW_NAME = 'un_hud_flow'
local HUD_LAYOUT_VERSION = 17
local HUD_TITLE_NAME = 'un_hud_title'
local HUD_RESET_COUNTDOWN_NAME = 'un_hud_reset_countdown'
local HUD_MENU_NAME = 'un_hud_menu'
local FRAME_NAME = 'un_main_frame'
local FRAME_WIDTH_FRACTION = 0.72
local FRAME_MIN_WIDTH = 1050
local FRAME_MAX_WIDTH = 1900
local FRAME_SCREEN_MARGIN = 48
local CLOSE_NAME = 'un_main_close'
local CONTENT_NAME = 'un_main_content'
local NAVIGATION_NAME = 'un_main_navigation'
local NAV_HELP_NAME = 'un_nav_help'
local NAV_UBI_NAME = 'un_nav_ubi'
local NAV_PROPERTY_BUILD_NAME = 'un_nav_property_build'
local NAV_PROPERTY_NAME = 'un_nav_property'
local NAV_PLANETS_NAME = 'un_nav_planets'
local NAV_SHIPS_NAME = 'un_nav_ships'
local NAV_ADMIN_NAME = 'un_nav_admin'
local HELP_STORY_NAME = 'un_help_story'
local HELP_BRIEF_NAME = 'un_help_brief'
local HELP_ADVANCED_NAME = 'un_help_advanced'
local HELP_FULL_NAME = 'un_help_full'
local HELP_ADMIN_NAME = 'un_help_admin'
local HELP_DETAILS_NAME = 'un_help_details'
local PROPERTY_ACCESS_NAME = 'un_property_access'
local PROPERTY_ACCESS_SECTION_NAME = 'un_property_access_section'
local PROPERTY_PLANET_TABS_NAME = 'un_property_planet_tabs'
local PROPERTY_HEADER_NAME = 'un_property_header'
local PROPERTY_SALVAGE_BUTTON_NAME = 'un_property_salvage_button'
local PROPERTY_RENEW_BUTTON_NAME = 'un_property_renew_button'
local PROPERTY_EXPAND_BUTTON_NAME = 'un_property_expand_button'
local PROPERTY_MANAGEMENT_ACTIONS_NAME = 'un_property_management_actions'
local BALANCE_TABLE_NAME = 'un_ubi_balance_table'
local BALANCE_NAME = 'un_ubi_balance'
local STAMINA_NAME = 'un_stamina'
local UBI_PROGRESS_NAME = 'un_ubi_progress'
local UBI_PROGRESS_LABEL_NAME = 'un_ubi_progress_label'
local UBI_CLAIM_NAME = 'un_ubi_claim'
local STARTER_KIT_NAME = 'un_starter_kit'
local WOOD_SUPPLY_NAME = 'un_wood_supply'
local SHIP_STATUS_NAME = 'un_ship_status'
local SHIP_ACTIONS_NAME = 'un_ship_actions'
local SHIP_CREATE_NAME = 'un_ship_create'
local SHIP_SCUTTLE_NAME = 'un_ship_scuttle'
local SHIP_VISIBILITY_NAME = 'un_ship_visibility'
local SHIP_SCROLL_NAME = 'un_ship_scroll'
local SHIP_TABLE_NAME = 'un_ship_table'
local SHIP_VIEW_PREFIX = 'un_ship_view_'
local PROPERTY_SCROLL_NAME = 'un_property_scroll'
local PROPERTY_TABLE_NAME = 'un_property_table'
local PROPERTY_BUILD_FORM_NAME = 'un_property_build_form'
local PROPERTY_BUILD_NAME_NAME = 'un_property_build_name'
local PROPERTY_BUILD_TYPE_NAME = 'un_property_build_type'
local PROPERTY_BUILD_LEVEL_FLOW_NAME = 'un_property_build_level_flow'
local PROPERTY_BUILD_LEVEL_NAME = 'un_property_build_level'
local PROPERTY_BUILD_LEVEL_VALUE_NAME = 'un_property_build_level_value'
local PROPERTY_BUILD_DIMENSIONS_NAME = 'un_property_build_dimensions'
local PROPERTY_BUILD_HALF_LIFE_NAME = 'un_property_build_half_life'
local PROPERTY_BUILD_TOTAL_LIFE_NAME = 'un_property_build_total_life'
local PROPERTY_BUILD_PRICE_NAME = 'un_property_build_price'
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
local PLAYER_BROWSE_NAME = 'un_player_browse'
local PLAYER_PROFILE_BACK_NAME = 'un_player_profile_back'
local PLAYER_PROFILE_PERSONAL_NAME = 'un_player_profile_personal'
local PLANET_HEADER_NAME = 'un_planet_header'
local PLANET_ACTIONS_NAME = 'un_planet_actions'
local PLANET_ACCELERATE_NAME = 'un_planet_accelerate'
local PLANET_TABLE_NAME = 'un_planet_table'
local TECH_LEAK_COUNTDOWN_NAME = 'un_tech_leak_countdown'
local CRIME_ACTIONS_NAME = 'un_crime_actions'
local CRIME_STATUS_NAME = 'un_crime_status'
local CRIME_BUTTON_NAME = 'un_crime_button'
local FACTION_SWITCH_PREFIX = 'un_faction_switch_'
local ADMIN_SCROLL_NAME = 'un_admin_scroll'
local ADMIN_SETTINGS_TABLE_NAME = 'un_admin_settings_table'
local ADMIN_RENTAL_TABLE_NAME = 'un_admin_rental_table'
local DANGEROUS_ADMIN_ACTIONS = {
    ['admin-fill-stamina'] = true,
    ['admin-grant-experience'] = true,
    ['admin-grant-credit'] = true,
    ['admin-diplomacy-friendly'] = true,
    ['admin-diplomacy-hostile'] = true,
    ['admin-run-automatic-trades'] = true,
}

local ADMIN_NUMBER_SETTINGS = {
    {'personal_linked_chest_limit',
        'un.admin-setting-personal-linked-chest-limit'},
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
    {'planet_foreign_warning_early_minutes',
        'un.admin-setting-foreign-warning-early'},
    {'planet_foreign_warning_final_minutes',
        'un.admin-setting-foreign-warning-final'},
    {'faction_friendly_to_hostile_percent',
        'un.admin-setting-faction-friendly-to-hostile'},
    {'faction_hostile_to_friendly_percent',
        'un.admin-setting-faction-hostile-to-friendly'},
    {'property_tax_percent', 'un.admin-setting-property-tax'},
    {'property_self_purchase_tax_multiplier',
        'un.admin-setting-property-self-purchase-tax'},
    {'property_tax_market_share_percent',
        'un.admin-setting-property-tax-market-share'},
    {'market_base_price_multiplier',
        'un.admin-setting-market-base-price-multiplier',
        'un.admin-setting-market-base-price-multiplier-tooltip'},
    {'market_item_depth_multiplier', 'un.admin-setting-market-item-depth',
        'un.admin-setting-market-item-depth-tooltip'},
    {'market_coin_depth_multiplier', 'un.admin-setting-market-coin-depth',
        'un.admin-setting-market-coin-depth-tooltip'},
    {'property_price_factor', 'un.admin-setting-property-factor'},
    {'technology_price_multiplier', 'un.admin-setting-technology-price'},
    {'spoil_time_modifier', 'un.admin-setting-spoil-time'},
    {'asteroid_spawning_rate', 'un.admin-setting-asteroid-rate'},
    {'property_limit_per_planet', 'un.admin-setting-property-limit'},
    {'property_salvage_percent', 'un.admin-setting-property-salvage'},
    {'property_expansion_cost_multiplier',
        'un.admin-setting-property-expansion-cost'},
    {'rental_property_width', 'un.admin-setting-rental-width'},
    {'rental_property_height', 'un.admin-setting-rental-height'},
    {'tech_leak_interval_hours', 'un.admin-setting-tech-leak-interval'},
    {'tech_leak_max_percent', 'un.admin-setting-tech-leak-strength'},
    {'tech_leak_max_affected', 'un.admin-setting-tech-leak-limit'},
}

local crime_error_caption
local update_crime_action

local PERSONAL_ACTION_WIDTH = 360
local LIST_SCROLL_MAX_HEIGHT = 520
local PROPERTY_SORT_FIELDS = {
    name = true,
    owner = true,
    expiry = true,
    price = true,
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

local function update_hud_title(player, hud)
    hud = hud or player.gui.top[HUD_FLOW_NAME]
    local title = hud and hud.valid and hud[HUD_TITLE_NAME]
    if not (title and title.valid) then return end
    local planet_name = factions.of_player(player)
    title.caption = planet_name and {
        '',
        {'un.hud-title'},
        '　',
        factions.display_name(planet_name),
    } or {'un.hud-title'}
end

local function update_hud_reset_countdown(player, hud)
    hud = hud or player.gui.top[HUD_FLOW_NAME]
    local label = hud and hud.valid and hud[HUD_RESET_COUNTDOWN_NAME]
    if not (label and label.valid) then return end

    local planet_name = factions.of_player(player)
    local record = planet_name and storage.public_planet_resets
        and storage.public_planet_resets[planet_name]
    if not record then
        label.caption = {'un.hud-reset-unknown'}
    elseif record.state ~= 'open' then
        label.caption = {'un.hud-reset-clearing'}
    elseif not settings.get('planet_resets_enabled') or not record.next_tick then
        label.caption = {'un.hud-reset-paused'}
    else
        local minutes = math.max(0, math.ceil(
            (record.next_tick - game.tick) / config.ticks_per_minute
        ))
        label.caption = {'un.hud-reset-countdown', minutes}
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
    for _, player in pairs(game.connected_players) do
        result[#result + 1] = player
    end
    table.sort(result, function(a, b)
        local a_self = a.index == viewer_index
        local b_self = b.index == viewer_index
        if a_self ~= b_self then return a_self end
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
    local hud = root[HUD_FLOW_NAME]
    if hud and hud.valid then
        local complete = hud.tags.layout_version == HUD_LAYOUT_VERSION
            and hud[HUD_TITLE_NAME]
            and hud[HUD_RESET_COUNTDOWN_NAME]
            and hud[M.hud_travel.name]
            and hud[HUD_MENU_NAME]
        if complete then
            update_hud_title(player, hud)
            update_hud_reset_countdown(player, hud)
            M.hud_travel.update(player, hud)
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
    local countdown = hud.add{
        type = 'label',
        name = HUD_RESET_COUNTDOWN_NAME,
        caption = {'un.hud-reset-unknown'},
    }
    countdown.style.font = 'default-bold'
    countdown.style.font_color = {r = 1, g = 1, b = 1}
    countdown.style.height = 40
    countdown.style.horizontal_align = 'center'
    countdown.style.vertical_align = 'center'
    countdown.style.left_margin = 6
    countdown.style.right_margin = 6
    local buttons = {
        {
            M.hud_travel.name,
            {'un.hud-property-cycle'},
            {'un.hud-property-cycle-tooltip'},
        },
        {HUD_MENU_NAME, {'un.hud-action-button'}, {'un.hud-menu-tooltip'}},
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
    update_hud_title(player, hud)
    update_hud_reset_countdown(player, hud)
    M.hud_travel.update(player, hud)
    return hud
end

local function property_price_name(property_id)
    return 'un_property_price_' .. tostring(property_id)
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
    if err == 'insufficient-experience' then
        return {'un.property-build-insufficient-experience'}
    end
    if err == 'insufficient-stamina' then return {'un.stamina-insufficient'} end
    if err == 'feature-disabled' then return {'un.feature-disabled'} end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'property-entry-hospice' then
        return {'un.property-enter-disabled-hospice'}
    end
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
    if (action == 'renew' or action == 'expand') and err == 'not-owner' then
        return {'un.property-manage-not-owner'}
    end
    if (action == 'renew' or action == 'expand') and err == 'not-inside' then
        return {'un.property-manage-not-inside'}
    end
    if action == 'renew' and (err == 'permanent'
            or err == 'not-player-built') then
        return {'un.property-renew-unavailable'}
    end
    if action == 'renew' and err == 'lifetime-full' then
        return {'un.property-renew-full'}
    end
    if action == 'expand' and err == 'construction-level-low' then
        return {'un.property-expand-level-required'}
    end
    if action == 'expand' and (err == 'permanent'
            or err == 'not-player-built' or err == 'not-expandable') then
        return {'un.property-expand-unavailable'}
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

local function planet_label(name)
    return {
        '',
        '[img=space-location/' .. name .. '] ',
        {'space-location-name.' .. name},
    }
end

local function is_public_planet(name)
    for _, planet_name in ipairs(config.public_planets) do
        if name == planet_name then return true end
    end
    return false
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

local function planet_acceleration_tooltip(player)
    local ok, err, planet_name = disasters.can_accelerate_reset(player)
    local base = {
        'un.planet-reset-accelerate-tooltip',
        planet_label(planet_name or factions.of_player(player) or 'nauvis'),
        config.planet_reset_acceleration_stamina_cost,
        math.floor(config.planet_reset_acceleration_fraction * 100 + 0.5),
        config.planet_reset_acceleration_min_remaining_minutes,
    }
    if ok then return base end
    return {
        '',
        base,
        '\n\n',
        {'un.planet-reset-accelerate-error-' .. tostring(err),
            config.planet_reset_acceleration_min_remaining_minutes,
            config.planet_reset_acceleration_stamina_cost},
    }
end

local function update_planet_acceleration_action(player, content)
    local actions = content[PLANET_ACTIONS_NAME]
    local button = actions and actions.valid and actions[PLANET_ACCELERATE_NAME]
    if not (button and button.valid) then return end
    local ok = disasters.can_accelerate_reset(player)
    button.enabled = ok
    button.tooltip = planet_acceleration_tooltip(player)
end

local function admin_setting_input_name(key)
    return 'un_admin_setting_' .. key
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

local function property_construction_caption(property)
    if type(property.construction_type) ~= 'string'
            or type(property.construction_level) ~= 'number' then
        if property.rental == true then
            return {'un.property-construction-public-rental'}
        end
        return ''
    end
    return {
        'un.property-construction-' .. property.construction_type,
        format_integer(property.construction_level),
    }
end

local function automatic_trade_tooltip(construction_type)
    if construction_type ~= 'cottage' then return nil end
    return {
        'un.property-auto-trade-balance-tooltip',
        math.max(1, math.floor(
            config.property_auto_trade_ticks / config.ticks_per_minute
        )),
    }
end

local function property_name_tooltip(property)
    local construction = property_construction_caption(property)
    local automatic_trade = automatic_trade_tooltip(
        property.construction_type
    )
    local hours = tostring(property.decay_ticks / config.ticks_per_hour)
    return {
        '',
        construction,
        automatic_trade and {'', '\n\n', automatic_trade} or '',
        construction ~= '' and {'', '\n\n'} or '',
        properties.feature_description(property),
        '\n\n',
        {'un.property-price-period-tooltip', hours},
    }
end

local function property_enter_tooltip(can_enter, enter_error)
    return {
        '',
        {'un.property-enter-tooltip'},
        not can_enter and {'', '\n\n', disabled_tooltip('enter', enter_error)}
            or '',
    }
end

local function property_buy_tooltip(player, property, can_buy, buy_error)
    local owner = properties.owner_name(property)
    local ownership
    if property.owner_index == player.index then
        ownership = {
            'un.property-buy-own-tooltip',
            settings.get('property_self_purchase_tax_multiplier'),
        }
    elseif owner then
        ownership = {'un.property-buy-owner-tooltip', owner}
    else
        ownership = {'un.property-buy-vacant-tooltip'}
    end
    return {
        '',
        ownership,
        not can_buy and {'', '\n\n', disabled_tooltip('buy', buy_error)} or '',
    }
end

local function set_frame_state(frame, page, property_revision)
    local tags = frame.tags
    tags.page = page
    tags.property_revision = property_revision or -1
    tags['list_refresh_' .. page] = math.floor(
        game.tick / config.gui_list_refresh_ticks
    )
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
    if field == 'name' then button.style.minimal_width = 240 end
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
    local actions = content[PROPERTY_MANAGEMENT_ACTIONS_NAME]
    local button = actions and actions.valid
        and actions[PROPERTY_SALVAGE_BUTTON_NAME]
    if not (button and button.valid) then return end
    local available, err, property, requirement
        = properties.salvage_at_player_availability(player)
    button.enabled = available
    button.tooltip = available and {
        'un.property-salvage-tooltip',
        settings.get('property_salvage_percent'),
        requirement and '[img=item/' .. requirement.pack .. ']' or '',
        requirement and format_integer(requirement.experience_refund) or '0',
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

local function update_property_renew_action(player, content)
    local actions = content[PROPERTY_MANAGEMENT_ACTIONS_NAME]
    local button = actions and actions.valid
        and actions[PROPERTY_RENEW_BUTTON_NAME]
    if not (button and button.valid) then return end
    local property = properties.property_at_player(player)
    local available, err, requirement
        = properties.renew_availability(player, property)
    button.enabled = available
    button.caption = {'un.property-renew'}
    button.tags = {
        action = 'property-renew',
        property_id = property and property.id or 0,
    }
    button.tooltip = requirement and {
        'un.property-renew-tooltip',
        '[img=item/' .. requirement.pack .. ']',
        {'item-name.' .. requirement.pack},
        format_integer(requirement.experience_cost),
        format_integer(requirement.stamina_cost),
        property and property.lifetime_hours or 0,
    } or {
        '',
        disabled_tooltip('renew', err),
        '\n\n',
        {'un.property-renew-rule-tooltip'},
    }
end

local function update_property_expand_action(player, content)
    local actions = content[PROPERTY_MANAGEMENT_ACTIONS_NAME]
    local button = actions and actions.valid
        and actions[PROPERTY_EXPAND_BUTTON_NAME]
    if not (button and button.valid) then return end
    local property = properties.property_at_player(player)
    local available, err, requirement
        = properties.expansion_availability(player, property)
    button.enabled = available
    button.caption = {'un.property-expand'}
    button.tags = {
        action = 'property-expand',
        property_id = property and property.id or 0,
    }
    button.tooltip = requirement and {
        'un.property-expand-tooltip',
        requirement.width,
        requirement.height,
        '[img=item/' .. requirement.pack .. ']',
        {'item-name.' .. requirement.pack},
        format_integer(requirement.experience_cost),
        format_integer(requirement.stamina_cost),
        requirement.source_level,
        requirement.target_level,
    } or {
        '',
        disabled_tooltip('expand', err),
        '\n\n',
        {
            'un.property-expand-rule-tooltip',
            settings.get('property_expansion_cost_multiplier'),
            config.property_expansion_stamina_cost,
        },
    }
end

local function render_property_table(player, frame, content)
    local old_header = content[PROPERTY_HEADER_NAME]
    if old_header and old_header.valid then old_header.destroy() end
    local old_tabs = content[PROPERTY_PLANET_TABS_NAME]
    if old_tabs and old_tabs.valid then old_tabs.destroy() end
    local old_management = content[PROPERTY_MANAGEMENT_ACTIONS_NAME]
    if old_management and old_management.valid then old_management.destroy() end
    local old_access = content[PROPERTY_ACCESS_SECTION_NAME]
    if old_access and old_access.valid then old_access.destroy() end
    local old_scroll = content[PROPERTY_SCROLL_NAME]
    if old_scroll and old_scroll.valid then old_scroll.destroy() end
    local old = content[PROPERTY_TABLE_NAME]
    if old and old.valid then old.destroy() end
    local own_planet = factions.of_player(player) or 'nauvis'
    local selected = frame.tags.property_planet
    if not is_public_planet(selected) then selected = own_planet end
    local read_only = selected ~= own_planet
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
    local faction_label = header.add{
        type = 'label',
        caption = {'un.property-my-faction', factions.display_name(own_planet)},
        tooltip = {'un.property-my-faction-tooltip'},
    }
    faction_label.style.font = 'default-semibold'
    add_info_sprite(header, {
        '',
        {'un.property-page-tooltip'},
        '\n\n',
        {
            'un.property-faction-survival-tooltip',
            settings.get('planet_foreign_warning_early_minutes'),
            settings.get('planet_foreign_warning_final_minutes'),
        },
    })
    local tabs = content.add{
        type = 'flow',
        name = PROPERTY_PLANET_TABS_NAME,
        direction = 'horizontal',
    }
    for _, planet_name in ipairs(config.public_planets) do
        tabs.add{
            type = 'button',
            caption = planet_label(planet_name),
            enabled = selected ~= planet_name,
            tags = {action = 'property-select-planet', planet = planet_name},
        }
    end
    if not read_only then
        local management_actions = content.add{
            type = 'flow',
            name = PROPERTY_MANAGEMENT_ACTIONS_NAME,
            direction = 'horizontal',
        }
        management_actions.add{
            type = 'button',
            name = PROPERTY_RENEW_BUTTON_NAME,
            caption = {'un.property-renew'},
            tags = {action = 'property-renew', property_id = 0},
        }
        if settings.get('property_expansion_enabled') then
            management_actions.add{
                type = 'button',
                name = PROPERTY_EXPAND_BUTTON_NAME,
                caption = {'un.property-expand'},
                tags = {action = 'property-expand', property_id = 0},
            }
        end
        if settings.get('property_salvage_enabled') then
            management_actions.add{
                type = 'button',
                name = PROPERTY_SALVAGE_BUTTON_NAME,
                caption = {'un.property-salvage'},
                tags = {action = 'property-salvage', property_id = 0},
            }
        end
    else
        header.add{type = 'label', caption = {'un.property-read-only'}}
    end
    if not read_only then
        update_property_renew_action(player, content)
        update_property_expand_action(player, content)
        update_property_salvage_action(player, content)
    end
    if not read_only and properties.owned_count(player.index) > 0 then
        render_property_access_section(player, content)
    end
    local scroll = add_list_scroll(content, PROPERTY_SCROLL_NAME)
    local list = scroll.add{
        type = 'table',
        name = PROPERTY_TABLE_NAME,
        column_count = read_only and 4 or 6,
        style = 'bordered_table',
    }
    add_property_sort_header(
        list, frame, 'name', {'un.property-column-name'}
    )
    if not read_only then
        list.add{type = 'label', caption = {'un.property-enter'}}
    end
    add_property_sort_header(
        list, frame, 'price', {'un.property-column-price'}
    )
    if not read_only then
        list.add{type = 'label', caption = {'un.property-buy'}}
    end
    add_property_sort_header(
        list, frame, 'expiry', {'un.property-column-lifetime'}
    )
    add_property_sort_header(
        list, frame, 'owner', {'un.property-column-owner'}
    )

    for _, property in ipairs(property_list) do
        local property_name = list.add{
            type = 'label',
            caption = properties.surface_display_name(property),
            tooltip = property_name_tooltip(property),
        }
        property_name.style.minimal_width = 240
        if not read_only then
            local can_enter, enter_error
                = properties.enter_availability(player, property)
            list.add{
                type = 'button',
                name = property_enter_name(property.id),
                caption = {'un.property-enter'},
                tooltip = property_enter_tooltip(can_enter, enter_error),
                enabled = can_enter,
                tags = {action = 'property-enter', property_id = property.id},
            }
        end
        local current_price = properties.current_price(property)
        list.add{
            type = 'label',
            name = property_price_name(property.id),
            caption = {'un.coin-amount',
                format_integer(current_price)},
            tooltip = {
                'un.property-price-with-change-tooltip',
                property_price_change_caption(property, current_price),
            },
        }
        if not read_only then
            local can_buy, buy_error
                = properties.buy_availability(player, property)
            list.add{
                type = 'button',
                name = property_buy_name(property.id),
                caption = property.owner_index == player.index
                    and {'un.property-mark-up'} or {'un.property-buy'},
                tooltip = property_buy_tooltip(
                    player, property, can_buy, buy_error
                ),
                enabled = can_buy,
                tags = {
                    action = 'property-buy',
                    property_id = property.id,
                },
            }
        end
        list.add{
            type = 'label',
            name = property_remaining_name(property.id),
            caption = property_lifetime_caption(property),
        }
        local owner = properties.owner_name(property)
        list.add{
            type = 'label',
            caption = owner or {'un.property-vacant'},
        }
    end
    set_frame_state(frame, 'property', storage.property_revision or 0)
    local tags = frame.tags
    tags.property_sort_field = sort_field
    tags.property_sort_descending = sort_descending
    tags.property_sort_bucket = math.floor(game.tick / config.ticks_per_minute)
    frame.tags = tags
end

local function property_build_planet(player)
    return factions.of_player(player)
end

local function update_property_build_page(player, content)
    local form = content[PROPERTY_BUILD_FORM_NAME]
    if not (form and form.valid) then return end
    local planet_name = property_build_planet(player)
    local build_type = form[PROPERTY_BUILD_TYPE_NAME]
    local level_flow = form[PROPERTY_BUILD_LEVEL_FLOW_NAME]
    local level_slider = level_flow and level_flow.valid
        and level_flow[PROPERTY_BUILD_LEVEL_NAME]
    local level_value = level_flow and level_flow.valid
        and level_flow[PROPERTY_BUILD_LEVEL_VALUE_NAME]
    local dimensions = form[PROPERTY_BUILD_DIMENSIONS_NAME]
    local half_life = form[PROPERTY_BUILD_HALF_LIFE_NAME]
    local total_life = form[PROPERTY_BUILD_TOTAL_LIFE_NAME]
    local price_label = form[PROPERTY_BUILD_PRICE_NAME]
    local cost_label = form[PROPERTY_BUILD_COST_NAME]
    local available_label = form[PROPERTY_BUILD_AVAILABLE_NAME]
    local stamina_cost_label = form[PROPERTY_BUILD_STAMINA_COST_NAME]
    local stamina_available_label = form[PROPERTY_BUILD_STAMINA_AVAILABLE_NAME]
    local button = form[PROPERTY_BUILD_BUTTON_NAME]
    if not (planet_name and build_type and level_slider and level_value
            and dimensions and half_life
            and total_life and price_label and cost_label
            and available_label and stamina_cost_label and stamina_available_label
            and button) then return end
    local selected_build_type = config.property_build_types[
        build_type.selected_index
    ]
    build_type.tooltip = selected_build_type
        and automatic_trade_tooltip(selected_build_type.key) or nil
    local current_level = experience.total_level(player.index)
    local selected_level = math.min(
        current_level,
        math.max(0, math.floor(level_slider.slider_value + 0.5))
    )
    level_slider.set_slider_minimum_maximum(0, math.max(1, current_level))
    level_slider.enabled = current_level > 0
    level_slider.slider_value = selected_level
    level_value.caption = {
        'un.property-build-level-value',
        selected_level,
        current_level,
    }
    local can_build, err, requirement = properties.build_availability(
        player,
        planet_name,
        build_type.selected_index,
        selected_level
    )
    if not requirement then return end
    dimensions.caption = {
        'un.property-build-generated-dimensions',
        requirement.size.width,
        requirement.size.height,
    }
    half_life.caption = {
        'un.property-build-generated-hours',
        requirement.lifetime.decay_hours,
    }
    total_life.caption = {
        'un.property-build-generated-hours',
        requirement.lifetime.hours,
    }
    price_label.caption = {'un.coin-amount', format_integer(requirement.initial_price)}
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
        caption = {'un.property-build-intro'},
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
    form.add{
        type = 'label',
        caption = {'un.property-build-type'},
    }
    local build_type_items = {}
    for _, option in ipairs(config.property_build_types) do
        build_type_items[#build_type_items + 1] = {
            'un.property-build-type-' .. option.key,
            (option.crime_chance_multiplier or 1) * 100,
        }
    end
    form.add{
        type = 'drop-down',
        name = PROPERTY_BUILD_TYPE_NAME,
        items = build_type_items,
        selected_index = 1,
        tooltip = {'un.property-build-type-tooltip'},
    }
    form.add{type = 'label', caption = {'un.property-build-level'}}
    local level_flow = form.add{
        type = 'flow',
        name = PROPERTY_BUILD_LEVEL_FLOW_NAME,
        direction = 'horizontal',
    }
    level_flow.style.vertical_align = 'center'
    local total_level = experience.total_level(player.index)
    local level_slider = level_flow.add{
        type = 'slider',
        name = PROPERTY_BUILD_LEVEL_NAME,
        minimum_value = 0,
        maximum_value = math.max(1, total_level),
        value = total_level,
        value_step = 1,
        discrete_values = true,
        tooltip = {'un.property-build-level-tooltip'},
    }
    level_slider.style.width = 260
    level_slider.enabled = total_level > 0
    level_flow.add{
        type = 'label',
        name = PROPERTY_BUILD_LEVEL_VALUE_NAME,
        caption = {'un.property-build-level-value', total_level, total_level},
        tooltip = {'un.property-build-level-tooltip'},
    }
    form.add{type = 'label', caption = {'un.property-build-dimensions'}}
    form.add{type = 'label', name = PROPERTY_BUILD_DIMENSIONS_NAME}
    local half_life_tooltip = {'un.property-build-half-life-tooltip'}
    form.add{
        type = 'label',
        caption = {'un.property-build-half-life'},
        tooltip = half_life_tooltip,
    }
    form.add{
        type = 'label',
        name = PROPERTY_BUILD_HALF_LIFE_NAME,
        tooltip = half_life_tooltip,
    }
    form.add{type = 'label', caption = {'un.property-build-total-life'}}
    form.add{type = 'label', name = PROPERTY_BUILD_TOTAL_LIFE_NAME}
    form.add{type = 'label', caption = {'un.property-build-initial-price'}}
    form.add{type = 'label', name = PROPERTY_BUILD_PRICE_NAME}
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
    local stamina_card = content.add{
        type = 'frame', name = 'un_stamina_card', direction = 'vertical',
    }
    stamina_card.style.horizontally_stretchable = true
    stamina_card.style.padding = 12
    local stamina_heading = stamina_card.add{type = 'flow', direction = 'horizontal'}
    stamina_heading.style.horizontally_stretchable = true
    stamina_heading.style.vertical_align = 'center'
    stamina_heading.add{
        type = 'label',
        caption = {'un.personal-stamina-section'},
        tooltip = stamina_tooltip,
    }
    stamina_card.add{
        type = 'label',
        name = STAMINA_NAME,
        tooltip = stamina_tooltip,
    }
    local stamina_progress = stamina_card.add{
        type = 'progressbar',
        name = 'un_stamina_progress',
        value = 0,
        tooltip = stamina_tooltip,
    }
    stamina_progress.style.horizontally_stretchable = true
    stamina_progress.style.minimal_width = PERSONAL_ACTION_WIDTH * 2 + 8
    stamina_progress.style.height = 28
    local actions = stamina_card.add{
        type = 'flow',
        name = 'un_personal_actions',
        direction = 'horizontal',
    }
    actions.style.horizontally_stretchable = true
    actions.style.top_margin = 8
    local kit = actions.add{
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
    local wood = actions.add{
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

    local coin_card = content.add{
        type = 'frame', name = 'un_coin_card', direction = 'vertical',
    }
    coin_card.style.horizontally_stretchable = true
    coin_card.style.padding = 12
    local balance = coin_card.add{
        type = 'flow',
        name = BALANCE_TABLE_NAME,
        direction = 'horizontal',
    }
    balance.style.horizontally_stretchable = true
    balance.style.vertical_align = 'center'
    balance.add{
        type = 'label',
        caption = {'un.personal-coin-section'},
        tooltip = coin_tooltip,
    }
    balance.add{
        type = 'label', name = BALANCE_NAME, tooltip = coin_tooltip,
    }
    coin_card.add{
        type = 'label',
        name = UBI_PROGRESS_LABEL_NAME,
        tooltip = ubi_tooltip,
    }
    local progress = coin_card.add{
        type = 'progressbar',
        name = UBI_PROGRESS_NAME,
        value = 0,
        tooltip = ubi_tooltip,
    }
    progress.style.horizontally_stretchable = true
    progress.style.minimal_width = PERSONAL_ACTION_WIDTH * 2 + 8
    progress.style.height = 28
    local claim = coin_card.add{
        type = 'button',
        name = UBI_CLAIM_NAME,
        caption = {'un.ubi-claim', 0, economy.get_ubi_capacity()},
        tooltip = ubi_tooltip,
    }
    claim.style.width = PERSONAL_ACTION_WIDTH
    claim.style.top_margin = 8
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
    content.add{
        type = 'switch',
        name = SHIP_VISIBILITY_NAME,
        switch_state = ships.is_public(player.index) and 'right' or 'left',
        left_label_caption = {'un.ship-visibility-private'},
        right_label_caption = {'un.ship-visibility-public'},
        left_label_tooltip = {'un.ship-visibility-tooltip'},
        right_label_tooltip = {'un.ship-visibility-tooltip'},
        tags = {action = 'ship-visibility'},
    }
    content.add{type = 'label', name = SHIP_STATUS_NAME}
end

local function render_experience_section(content, allow_conversion)
    local card = content.add{
        type = 'frame', name = 'un_experience_card', direction = 'vertical',
    }
    card.style.horizontally_stretchable = true
    card.style.padding = 12
    local heading = card.add{type = 'flow', direction = 'horizontal'}
    heading.style.horizontally_stretchable = true
    heading.style.vertical_align = 'center'
    heading.add{
        type = 'label',
        caption = {'un.experience-title'},
        tooltip = {'un.experience-tooltip'},
    }
    add_info_sprite(heading, {'un.experience-tooltip'})
    if allow_conversion ~= false then
        local convert = card.add{
            type = 'button',
            name = 'un_experience_convert',
            caption = {'un.experience-convert-backpack'},
            tooltip = {'un.experience-convert-backpack-tooltip'},
        }
        convert.style.width = PERSONAL_ACTION_WIDTH
        convert.style.top_margin = 8
    end
    local grid = card.add{
        type = 'table',
        name = EXPERIENCE_TABLE_NAME,
        column_count = 3,
        style = 'bordered_table',
    }
    grid.style.horizontally_stretchable = true
    grid.style.top_margin = 8
    for index, name in ipairs(config.science_pack_order) do
        grid.add{type = 'sprite', sprite = 'item/' .. name}
        local progress = grid.add{
            type = 'progressbar',
            name = experience_progress_name(index),
            value = 0,
        }
        progress.style.horizontally_stretchable = true
        progress.style.minimal_width = 240
        local amount = grid.add{
            type = 'label', name = experience_amount_name(index),
        }
        amount.style.minimal_width = 260
    end
    card.add{type = 'label', name = EXPERIENCE_SUMMARY_NAME}
end

local function update_experience_section(subject, content)
    local card = content and content.valid and content.un_experience_card
    local grid = card and card.valid and card[EXPERIENCE_TABLE_NAME]
    if not (subject and subject.valid and grid and grid.valid) then return end
    local data = experience.get(subject.index)
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
    local summary = card[EXPERIENCE_SUMMARY_NAME]
    if summary and summary.valid then
        summary.caption = {
            'un.experience-summary',
            experience.total_level(subject.index),
        }
    end
end

local function render_overview_page(player, frame, content)
    local actions = content.add{type = 'flow', direction = 'horizontal'}
    actions.add{
        type = 'button',
        name = PLAYER_BROWSE_NAME,
        caption = {'un.player-browse'},
        tooltip = {'un.player-browse-tooltip'},
    }
    render_ubi_section(content)
    render_experience_section(content, true)
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
    local list_data = ships.list(player.index)
    local scroll = add_list_scroll(content, SHIP_SCROLL_NAME)
    local list = scroll.add{
        type = 'table',
        name = SHIP_TABLE_NAME,
        column_count = 5,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.ship-column-owner'}}
    list.add{type = 'label', caption = {'un.ship-column-name'}}
    list.add{type = 'label', caption = {'un.ship-column-view'}}
    list.add{type = 'label', caption = {'un.ship-column-orbit'}}
    list.add{type = 'label', caption = {'un.ship-column-remaining'}}
    if #list_data == 0 then
        list.add{type = 'label', caption = {'un.ship-list-empty'}}
        list.add{type = 'label', caption = ''}
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
                type = 'button',
                name = SHIP_VIEW_PREFIX .. tostring(item.index),
                caption = {'un.ship-view'},
                tooltip = {'un.ship-view-tooltip'},
                tags = {action = 'ship-view', platform_index = item.index},
            }
            list.add{
                type = 'label',
                caption = planet_label(item.record.planet_name
                    or config.ship_home_planet),
            }
            list.add{
                type = 'label',
                name = ship_remaining_name(item.index),
                caption = {
                    'un.ship-remaining-hours',
                    math.ceil(
                        math.max(0, ships.left_ticks(item.record))
                            / config.ticks_per_hour
                    ),
                },
            }
        end
    end
    set_frame_state(frame, 'ships')
    local tags = frame.tags
    tags.ship_signature = ship_signature(list_data)
    frame.tags = tags
end

local faction_element_name
local update_factions_page

local function render_planets_page(player, frame, content)
    local leak_left = technology_decay.left_ticks()
    local header = content.add{
        type = 'flow',
        name = PLANET_HEADER_NAME,
        direction = 'vertical',
    }
    local summary = header.add{type = 'flow', direction = 'horizontal'}
    summary.style.vertical_align = 'center'
    summary.add{
        type = 'label',
        caption = {
            'un.faction-current-summary',
            factions.display_name(factions.of_player(player) or 'nauvis'),
        },
    }
    add_info_sprite(summary, {
        '',
        {
            'un.faction-page-tooltip',
            settings.get('faction_friendly_to_hostile_percent'),
            settings.get('faction_hostile_to_friendly_percent'),
            settings.get('surface_hidden_from_foreign_factions')
                and {'un.yes'} or {'un.no'},
            settings.get('surface_hidden_from_home_faction')
                and {'un.yes'} or {'un.no'},
        },
        '\n\n',
        {'un.faction-aquilo-neutral'},
    })
    add_info_sprite(summary, {'un.planet-page-note'})
    header.add{
        type = 'label',
        name = TECH_LEAK_COUNTDOWN_NAME,
        caption = leak_left and {
            'un.tech-leak-countdown',
            format_countdown(leak_left),
        } or {'un.tech-leak-paused'},
        tooltip = {'un.tech-leak-tooltip'},
    }
    local actions = content.add{
        type = 'flow',
        name = PLANET_ACTIONS_NAME,
        direction = 'horizontal',
    }
    actions.add{
        type = 'button',
        name = PLANET_ACCELERATE_NAME,
        caption = {
            'un.planet-reset-accelerate-button',
            config.planet_reset_acceleration_stamina_cost,
        },
    }
    update_planet_acceleration_action(player, content)
    local list = content.add{
        type = 'table',
        name = PLANET_TABLE_NAME,
        column_count = 8,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.faction-column-name'}}
    list.add{type = 'label', caption = {'un.planet-column-countdown'}}
    list.add{type = 'label', caption = {'un.planet-column-traits'}}
    list.add{type = 'label', caption = {'un.faction-column-relation'}}
    list.add{type = 'label', caption = {'un.faction-column-population'}}
    list.add{type = 'label', caption = {'un.faction-column-properties'}}
    list.add{type = 'label', caption = {'un.faction-column-ships'}}
    list.add{type = 'label', caption = {'un.faction-column-action'}}
    for _, item in ipairs(disasters.list()) do
        list.add{type = 'label', caption = factions.display_name(item.name)}
        list.add{
            type = 'label',
            name = planet_countdown_name(item.name),
            caption = item.paused
                and {'un.planet-countdown-paused',
                    format_countdown(item.left_ticks)}
                or item.left_ticks
                and format_countdown(item.left_ticks)
                or {'un.planet-countdown-clearing'},
        }
        local traits = list.add{
            type = 'flow',
            name = planet_traits_name(item.name),
            direction = 'vertical',
        }
        render_planet_traits(traits, item)
        list.add{type = 'label', name = faction_element_name('status', item.name)}
        list.add{type = 'label', name = faction_element_name('population', item.name)}
        list.add{type = 'label', name = faction_element_name('properties', item.name)}
        list.add{type = 'label', name = faction_element_name('ships', item.name)}
        list.add{
            type = 'button',
            name = FACTION_SWITCH_PREFIX .. item.name,
            caption = {'un.faction-switch'},
            tags = {action = 'faction-switch', planet = item.name},
        }
    end
    set_frame_state(frame, 'planets')
    update_factions_page(player, content)
end

faction_element_name = function(kind, planet_name)
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

local function collect_faction_statistics()
    local ship_list = ships.list()
    local property_counts = {}
    for _, property in ipairs(properties.list()) do
        local planet_name = property.sample_planet
        property_counts[planet_name] = (property_counts[planet_name] or 0) + 1
    end
    local result = {}
    for _, planet_name in ipairs(config.public_planets) do
        result[planet_name] = faction_statistics(
            planet_name,
            ship_list,
            property_counts
        )
    end
    return result
end

update_factions_page = function(player, content, statistics_by_planet)
    local list = content[PLANET_TABLE_NAME]
    if not (list and list.valid) then return end
    local current = factions.of_player(player)
    statistics_by_planet = statistics_by_planet
        or collect_faction_statistics()
    for _, planet_name in ipairs(config.public_planets) do
        local data = statistics_by_planet[planet_name]
        local status = list[faction_element_name('status', planet_name)]
        local population = list[faction_element_name('population', planet_name)]
        local property_count = list[faction_element_name('properties', planet_name)]
        local ship_count = list[faction_element_name('ships', planet_name)]
        local button = list[FACTION_SWITCH_PREFIX .. planet_name]
        local switch_cost = factions.switch_stamina_cost(planet_name)
        local switch_coin = factions.switch_coin_cost(planet_name)
        local can_switch, switch_error, switch_detail
            = factions.switch_availability(player, planet_name)
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
            button.enabled = can_switch
            if current == planet_name then
                button.tooltip = {'un.faction-already-current'}
            elseif switch_error == 'faction-online-time' then
                button.tooltip = {
                    '',
                    online_requirement_caption(
                        player,
                        'faction_switch_min_online_hours',
                        'un.faction-online-required'
                    ),
                    '\n\n',
                    planet_name == 'nauvis' and {
                        'un.faction-switch-tooltip-free',
                        planet_label(planet_name),
                        config.faction_switch_nauvis_respawn_seconds,
                    } or {
                        'un.faction-switch-tooltip',
                        planet_label(planet_name),
                        switch_cost,
                        switch_coin,
                        config.faction_switch_cooldown_hours,
                    },
                }
            else
                local base_tooltip = planet_name == 'nauvis' and {
                    'un.faction-switch-tooltip-free',
                    planet_label(planet_name),
                    config.faction_switch_nauvis_respawn_seconds,
                } or {
                    'un.faction-switch-tooltip',
                    planet_label(planet_name),
                    switch_cost,
                    switch_coin,
                    config.faction_switch_cooldown_hours,
                }
                local reason = switch_error == 'faction-target-location'
                    and {'un.faction-target-location-required',
                        planet_label(planet_name)}
                    or switch_error == 'faction-cooldown'
                    and {'un.faction-switch-cooldown', format_countdown(switch_detail)}
                    or switch_error == 'insufficient-credit'
                    and {'un.credit-insufficient'}
                    or switch_error == 'insufficient-stamina'
                    and {'un.suicide-stamina-insufficient'}
                button.tooltip = reason and {
                    '', reason, '\n\n', base_tooltip,
                } or base_tooltip
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

function M.render_crime_page(player, frame, content)
    local actions = content.add{
        type = 'flow',
        name = CRIME_ACTIONS_NAME,
        direction = 'horizontal',
    }
    actions.style.vertical_align = 'center'
    actions.add{
        type = 'button',
        name = CRIME_BUTTON_NAME,
        caption = {'un.crime-button'},
    }
    actions.add{type = 'label', name = CRIME_STATUS_NAME}
    update_crime_action(player, content)

    local candidates, planet_name, context_error = crime.list_targets(player)
    if not planet_name then
        content.add{
            type = 'label',
            caption = crime_error_caption(context_error),
        }
        set_frame_state(frame, 'crime', storage.property_revision or 0)
        return
    end
    content.add{
        type = 'label',
        caption = {
            'un.crime-page-summary',
            planet_label(planet_name),
            #candidates,
        },
    }
    if #candidates == 0 then
        content.add{type = 'label', caption = {'un.crime-list-empty'}}
        set_frame_state(frame, 'crime', storage.property_revision or 0)
        return
    end

    local scroll = add_list_scroll(content, 'un_crime_scroll')
    local list = scroll.add{
        type = 'table',
        name = 'un_crime_table',
        column_count = 5,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.property-column-name'}}
    list.add{type = 'label', caption = {'un.property-column-price'}}
    list.add{type = 'label', caption = {'un.property-column-lifetime'}}
    list.add{type = 'label', caption = {'un.property-column-owner'}}
    list.add{type = 'label', caption = {'un.crime-column-chance'}}
    for _, property in ipairs(candidates) do
        local name = list.add{
            type = 'label',
            caption = properties.surface_display_name(property),
            tooltip = property_name_tooltip(property),
        }
        name.style.minimal_width = 240
        list.add{
            type = 'label',
            caption = {'un.coin-amount',
                format_integer(properties.current_price(property))},
        }
        list.add{type = 'label', caption = property_lifetime_caption(property)}
        list.add{
            type = 'label',
            caption = properties.owner_name(property) or {'un.property-vacant'},
        }
        local percent = crime.success_chance(property) * 100
        list.add{
            type = 'label',
            caption = percent >= 1 and string.format('%.2f%%', percent)
                or string.format('%.4f%%', percent),
            tooltip = {'un.crime-chance-tooltip'},
        }
    end
    set_frame_state(frame, 'crime', storage.property_revision or 0)
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
    summary.add{type = 'label', caption = linked_inventory.active_count()}

    local dangerous_actions_enabled
        = frame.tags.admin_dangerous_actions == true
    local dangerous_switch = scroll.add{
        type = 'switch',
        left_label_caption = {'un.admin-dangerous-actions-hidden'},
        right_label_caption = {'un.admin-dangerous-actions-visible'},
        left_label_tooltip = {'un.admin-dangerous-actions-tooltip'},
        right_label_tooltip = {'un.admin-dangerous-actions-tooltip'},
        switch_state = dangerous_actions_enabled and 'right' or 'left',
        allow_none_state = false,
        tags = {action = 'admin-dangerous-actions'},
    }
    dangerous_switch.style.top_margin = 8
    if dangerous_actions_enabled then
        local actions = scroll.add{type = 'flow', direction = 'horizontal'}
        actions.style.top_margin = 8
        actions.add{
            type = 'button',
            caption = {'un.admin-fill-stamina'},
            tooltip = {'un.admin-fill-stamina-tooltip', config.stamina_max},
            tags = {action = 'admin-fill-stamina'},
        }
        actions.add{
            type = 'button',
            caption = {'un.admin-grant-experience'},
            tooltip = {'un.admin-grant-experience-tooltip',
                config.admin_experience_grant},
            tags = {action = 'admin-grant-experience'},
        }
        actions.add{
            type = 'button',
            caption = {'un.admin-grant-credit'},
            tooltip = {'un.admin-grant-credit-tooltip', config.admin_credit_grant},
            tags = {action = 'admin-grant-credit'},
        }
        actions.add{
            type = 'button',
            caption = {'un.admin-diplomacy-friendly'},
            tooltip = {'un.admin-diplomacy-friendly-tooltip'},
            tags = {action = 'admin-diplomacy-friendly'},
        }
        actions.add{
            type = 'button',
            caption = {'un.admin-diplomacy-hostile'},
            tooltip = {'un.admin-diplomacy-hostile-tooltip'},
            tags = {action = 'admin-diplomacy-hostile'},
        }
        actions.add{
            type = 'button',
            caption = {'un.admin-run-automatic-trades'},
            tooltip = {'un.admin-run-automatic-trades-tooltip'},
            tags = {action = 'admin-run-automatic-trades'},
        }
    end

    scroll.add{type = 'line'}
    scroll.add{
        type = 'label',
        caption = {'un.admin-rentals-title'},
        style = 'heading_2_label',
    }
    local rental_help = scroll.add{
        type = 'label',
        caption = {'un.admin-rentals-help'},
    }
    rental_help.style.single_line = false
    rental_help.style.maximal_width = 720
    local rental_table = scroll.add{
        type = 'table',
        name = ADMIN_RENTAL_TABLE_NAME,
        column_count = 5,
        style = 'bordered_table',
    }
    rental_table.add{
        type = 'label', caption = {'un.admin-rental-column-planet'},
    }
    rental_table.add{
        type = 'label', caption = {'un.admin-rental-column-total'},
    }
    rental_table.add{
        type = 'label', caption = {'un.admin-rental-column-vacant'},
    }
    rental_table.add{type = 'label', caption = ''}
    rental_table.add{type = 'label', caption = ''}
    for _, planet_name in ipairs(config.public_planets) do
        local total, vacant = properties.rental_counts(planet_name)
        rental_table.add{type = 'label', caption = planet_label(planet_name)}
        rental_table.add{type = 'label', caption = total}
        rental_table.add{type = 'label', caption = vacant}
        rental_table.add{
            type = 'button',
            caption = {'un.admin-rental-remove'},
            enabled = vacant > 0,
            tooltip = vacant > 0 and {'un.admin-rental-remove-tooltip'}
                or {'un.admin-rental-no-vacant-tooltip'},
            tags = {action = 'admin-rental-remove', planet = planet_name},
        }
        rental_table.add{
            type = 'button',
            caption = {'un.admin-rental-add'},
            enabled = #properties.list(planet_name)
                < settings.get('property_limit_per_planet'),
            tooltip = {'un.admin-rental-add-tooltip',
                settings.get('rental_property_width'),
                settings.get('rental_property_height')},
            tags = {action = 'admin-rental-add', planet = planet_name},
        }
    end

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
        setting_table.add{
            type = 'label',
            caption = {spec[2]},
            tooltip = spec[3] and {spec[3]} or nil,
        }
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
                or key == 'faction_friendly_to_hostile_percent'
                or key == 'faction_hostile_to_friendly_percent'
                or key == 'property_tax_percent'
                or key == 'property_self_purchase_tax_multiplier'
                or key == 'property_tax_market_share_percent'
                or key == 'market_base_price_multiplier'
                or key == 'market_item_depth_multiplier'
                or key == 'market_coin_depth_multiplier'
                or key == 'property_price_factor'
                or key == 'technology_price_multiplier'
                or key == 'spoil_time_modifier'
                or key == 'asteroid_spawning_rate'
                or key == 'tech_leak_interval_hours'
                or key == 'tech_leak_max_percent'
                or key == 'property_salvage_percent'
                or key == 'property_expansion_cost_multiplier'
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
        right_label_caption = {'un.admin-setting-property-expansion-enabled'},
        switch_state = settings.get('property_expansion_enabled')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'property_expansion_enabled',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-property-salvage-enabled'},
        switch_state = settings.get('property_salvage_enabled')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'property_salvage_enabled',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-crime-enabled'},
        switch_state = settings.get('crime_enabled') and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'crime_enabled',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-science-conversion-notifications'},
        switch_state = settings.get('science_conversion_notifications')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'science_conversion_notifications',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-property-access'},
        switch_state = settings.get('admin_property_access') and 'right' or 'left',
        allow_none_state = false,
        tags = {action = 'admin-setting-switch', setting = 'admin_property_access'},
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-hide-foreign-surfaces'},
        left_label_tooltip = {'un.admin-setting-surface-visibility-tooltip'},
        right_label_tooltip = {'un.admin-setting-surface-visibility-tooltip'},
        switch_state = settings.get('surface_hidden_from_foreign_factions')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'surface_hidden_from_foreign_factions',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-hide-home-surfaces'},
        left_label_tooltip = {'un.admin-setting-surface-visibility-tooltip'},
        right_label_tooltip = {'un.admin-setting-surface-visibility-tooltip'},
        switch_state = settings.get('surface_hidden_from_home_faction')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'surface_hidden_from_home_faction',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-setting-linked-chest-all-planets'},
        right_label_caption = {'un.admin-setting-linked-chest-home-only'},
        switch_state = settings.get('personal_linked_chest_home_planet_only')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'personal_linked_chest_home_planet_only',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-linked-chest-hospice'},
        switch_state = settings.get('personal_linked_chest_allow_hospice')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'personal_linked_chest_allow_hospice',
        },
    }
    switches.add{
        type = 'switch',
        left_label_caption = {'un.admin-disabled'},
        right_label_caption = {'un.admin-setting-linked-chest-property'},
        switch_state = settings.get('personal_linked_chest_allow_property')
            and 'right' or 'left',
        allow_none_state = false,
        tags = {
            action = 'admin-setting-switch',
            setting = 'personal_linked_chest_allow_property',
        },
    }

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

local function add_help_card(parent, title, tooltip)
    local card = parent.add{type = 'frame', direction = 'vertical'}
    card.style.horizontally_stretchable = true
    card.style.padding = 12
    local heading_row = card.add{type = 'flow', direction = 'horizontal'}
    heading_row.style.vertical_align = 'center'
    local heading = heading_row.add{type = 'label', caption = title}
    heading.style.font = 'default-large-bold'
    heading.style.bottom_margin = 6
    if tooltip then
        heading_row.add{
            type = 'sprite',
            sprite = 'virtual-signal/signal-info',
            tooltip = tooltip,
        }
    end
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
        caption = mode == 'faction' and {'un.help-faction-title'}
            or mode == 'story' and {'un.help-story-title'}
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
    local faction = modes.add{
        type = 'button',
        name = 'un_help_faction',
        caption = {'un.help-mode-faction'},
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
    faction.enabled = mode ~= 'faction'
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

    if mode == 'faction' then
        local background = add_help_card(
            details,
            {'un.help-card-story'},
            {'un.help-story-background-detail'}
        )
        add_help_line(background, {'un.help-story-background'})
        add_help_gap(details)
        local forces = add_help_card(
            details,
            {'un.help-card-factions'},
            {
                '',
                {'un.help-story-factions-detail'},
                '\n\n',
                {
                    'un.help-detail-tech-leak',
                    settings.get('tech_leak_interval_hours'),
                },
                '\n\n',
                {
                    'un.help-detail-tech-leak-formula',
                    settings.get('tech_leak_max_percent'),
                    settings.get('tech_leak_max_affected'),
                    config.tech_leak_chance_multiplier_by_planet.aquilo,
                },
            }
        )
        add_help_line(forces, {'un.help-story-factions'})
        add_help_gap(details)
        local foreign = add_help_card(
            details,
            {'un.help-card-foreign-expedition'},
            {'un.help-story-foreign-detail'}
        )
        add_help_line(foreign, {'un.help-story-foreign'})
        add_help_gap(details)
        local diplomacy = add_help_card(
            details,
            {'un.help-card-diplomacy'},
            {'un.help-story-diplomacy-detail'}
        )
        add_help_line(diplomacy, {'un.help-story-diplomacy'})
        add_help_gap(details)
        local switching = add_help_card(
            details,
            {'un.help-card-faction-switch'},
            {'un.help-story-faction-switch-detail'}
        )
        add_help_line(switching, {'un.help-story-faction-switch'})
    elseif mode == 'story' then
        local ownership = add_help_card(
            details,
            {'un.help-property-card-ownership'},
            {'un.help-property-ownership-detail'}
        )
        add_help_line(ownership, {'un.help-property-ownership-summary'})
        add_help_gap(details)

        local trading = add_help_card(
            details,
            {'un.help-property-card-trading'},
            {
                '',
                {
                    'un.help-detail-property-price',
                    config.property_price_cap,
                    settings.get('property_price_factor'),
                },
                '\n\n',
                {
                    'un.help-detail-property-trade',
                    settings.get('property_tax_percent'),
                    settings.get('property_salvage_percent'),
                    settings.get('property_self_purchase_tax_multiplier'),
                },
            }
        )
        add_help_line(trading, {'un.help-property-trading-summary'})
        add_help_gap(details)

        local lifecycle = add_help_card(
            details,
            {'un.help-property-card-lifecycle'},
            {'un.help-detail-property-basic'}
        )
        add_help_line(lifecycle, {'un.help-property-lifecycle-summary'})
        add_help_gap(details)

        local access = add_help_card(
            details,
            {'un.help-property-card-access'},
            {'un.help-property-access-detail'}
        )
        add_help_line(access, {'un.help-property-access-summary'})
    elseif mode == 'brief' then
        local travel = add_help_card(
            details,
            {'un.help-shift-card-travel'},
            {
                '',
                {
                    'un.help-shift-travel-detail',
                    settings.get('planet_foreign_warning_early_minutes'),
                    settings.get('planet_foreign_warning_final_minutes'),
                },
                '\n\n',
                {
                    'un.help-detail-reset-schedule',
                    settings.get('planet_reset_min_hours'),
                    settings.get('planet_reset_max_hours'),
                },
                '\n\n',
                {
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
                },
            }
        )
        add_help_line(travel, {'un.help-shift-travel-summary'})
        add_help_gap(details)

        local logistics = add_help_card(
            details,
            {'un.help-shift-card-logistics'},
            {
                'un.help-shift-logistics-detail',
                settings.get('personal_linked_chest_limit'),
            }
        )
        add_help_line(logistics, {'un.help-shift-logistics-summary'})
        add_help_gap(details)

        local advice = add_help_card(
            details,
            {'un.help-shift-card-advice'},
            {'un.help-shift-advice-detail'}
        )
        add_help_line(advice, {'un.help-shift-advice-summary'})
    elseif mode == 'advanced' then
        local experience_tooltip = {
            '',
            {
                'un.help-detail-science',
                config.science_conversion_ticks / config.ticks_per_minute,
                config.science_offline_conversion_ticks
                    / config.ticks_per_minute,
                config.science_offline_conversion_max_hours,
            },
            '\n\n',
            {'un.experience-tooltip'},
            '\n\n',
            {
                'un.help-detail-experience-effects',
                config.ship_base_width,
                config.ship_width_per_level,
                settings.get('ship_life_hours'),
                settings.get('property_tax_percent'),
            },
        }
        local experience_card = add_help_card(
            details,
            {'un.help-factory-card-experience'},
            experience_tooltip
        )
        add_help_line(experience_card, {'un.help-factory-experience-summary'})
        add_help_gap(details)

        local building_tooltip = {
            '',
            {'un.help-detail-property-build'},
            '\n\n',
            {
                'un.help-detail-property-build-formula',
                config.property_build_experience_base,
                config.property_build_experience_per_level,
                config.property_build_stamina_cost,
                settings.get('property_limit_per_planet'),
                config.property_price_cap,
                config.property_build_experience_multiplier,
            },
            '\n\n',
            {'un.help-detail-property-basic'},
        }
        local building = add_help_card(
            details,
            {'un.help-factory-card-building'},
            building_tooltip
        )
        add_help_line(building, {'un.help-factory-building-summary'})
        add_help_gap(details)

        local logistics = add_help_card(
            details,
            {'un.help-factory-card-logistics'},
            {
                'un.help-detail-linked-chest',
                settings.get('personal_linked_chest_limit'),
            }
        )
        add_help_line(logistics, {'un.help-factory-logistics-summary'})
        add_help_gap(details)

        local robots = add_help_card(
            details,
            {'un.help-factory-card-robots'},
            {
                'un.help-detail-logistics-limits',
                config.logistic_network_roboport_limit,
                config.logistic_network_logistic_robot_limit,
            }
        )
        add_help_line(robots, {'un.help-factory-robots-summary'})
    elseif mode == 'full' then
        local manual = add_help_card(
            details,
            {'un.help-market-card-manual'},
            {'un.market-tooltip'}
        )
        add_help_line(manual, {'un.help-market-manual-summary'})
        add_help_gap(details)

        local automatic = add_help_card(
            details,
            {'un.help-market-card-automatic'},
            {
                'un.property-auto-trade-balance-tooltip',
                config.property_auto_trade_ticks / config.ticks_per_minute,
            }
        )
        add_help_line(automatic, {'un.help-market-automatic-summary'})
        add_help_gap(details)

        local prices = add_help_card(
            details,
            {'un.help-market-card-prices'},
            {'un.help-market-prices-detail'}
        )
        add_help_line(prices, {'un.help-market-prices-summary'})
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

        local starter_resources = add_help_card(details, {
            'un.help-admin-starter-resources-heading',
        })
        add_help_line(starter_resources, {
            'un.help-admin-starter-resources',
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
    for _, player in pairs(game.connected_players) do
        parts[#parts + 1] = tostring(player.index)
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
        name = PLAYER_PROFILE_PERSONAL_NAME,
        caption = {'un.player-back-personal'},
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
        column_count = 7,
        style = 'bordered_table',
    }
    list.add{type = 'label', caption = {'un.player-column-name'}}
    list.add{type = 'label', caption = {'un.player-column-faction'}}
    list.add{type = 'label', caption = {'un.player-column-online-hours'}}
    list.add{type = 'label', caption = {'un.player-column-locale'}}
    list.add{type = 'label', caption = {'un.player-column-coins'}}
    list.add{type = 'label', caption = {'un.player-column-total-level'}}
    list.add{type = 'label', caption = {'un.player-column-friend'}}

    for _, player in ipairs(sorted_players(viewer.index)) do
        list.add{
            type = 'button',
            caption = player.name,
            tooltip = {'un.player-view-profile-tooltip'},
            tags = {action = 'player-view-profile', target_index = player.index},
        }
        list.add{
            type = 'label',
            name = player_element_name('faction', player.index),
            caption = player_faction_icon(player),
            tooltip = factions.display_name(factions.of_player(player)),
        }
        list.add{
            type = 'label',
            name = player_element_name('online', player.index),
            caption = format_hours(playtime.ticks(player)),
        }
        list.add{
            type = 'label',
            name = player_element_name('locale', player.index),
            caption = player.locale,
        }
        list.add{
            type = 'label',
            name = player_element_name('coins', player.index),
            caption = format_integer(economy.get_balance(player.index)),
        }
        list.add{
            type = 'label',
            name = player_element_name('level', player.index),
            caption = format_integer(experience.total_level(player.index)),
        }
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

local function render_player_profile(viewer, frame, content)
    local target = game.get_player(tonumber(frame.tags.profile_player_index))
    if not (target and target.valid) then
        render_overview_page(viewer, frame, content)
        return
    end
    local actions = content.add{type = 'flow', direction = 'horizontal'}
    actions.add{
        type = 'button',
        name = PLAYER_PROFILE_BACK_NAME,
        caption = {'un.player-back-list'},
    }
    actions.add{
        type = 'button',
        name = PLAYER_PROFILE_PERSONAL_NAME,
        caption = {'un.player-back-personal'},
    }
    local heading = content.add{
        type = 'label',
        caption = {'un.player-profile-title', target.name},
    }
    heading.style.font = 'default-large-bold'
    local summary = content.add{
        type = 'table',
        column_count = 2,
        style = 'bordered_table',
    }
    summary.add{type = 'label', caption = {'un.player-column-faction'}}
    summary.add{
        type = 'label',
        caption = player_faction_icon(target),
        tooltip = factions.display_name(factions.of_player(target)),
    }
    summary.add{type = 'label', caption = {'un.player-column-online-hours'}}
    summary.add{type = 'label', caption = format_hours(playtime.ticks(target))}
    summary.add{type = 'label', caption = {'un.player-column-locale'}}
    summary.add{type = 'label', caption = target.locale}
    summary.add{type = 'label', caption = {'un.player-column-coins'}}
    summary.add{
        type = 'label',
        caption = format_integer(economy.get_balance(target.index)),
    }
    summary.add{type = 'label', caption = {'un.player-column-total-level'}}
    summary.add{
        type = 'label',
        caption = format_integer(experience.total_level(target.index)),
    }
    render_experience_section(content, false)
    update_experience_section(target, content)
    set_frame_state(frame, 'player-profile')
end

local function render_page(player, page)
    local frame = player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then return end
    local content = frame[CONTENT_NAME]
    if not (content and content.valid) then return end
    if page == 'admin' and not player.admin then page = 'help' end
    if page == 'crime' and not settings.get('crime_enabled') then
        page = 'property'
    end
    content.clear()

    if page == 'help' then
        render_help_page(player, frame, content)
    elseif page == 'overview' then
        render_overview_page(player, frame, content)
    elseif page == 'market' then
        M.market_gui.render(player, frame, content)
    elseif page == 'property-build' then
        render_property_build_page(player, frame, content)
    elseif page == 'property' then
        render_property_table(player, frame, content)
    elseif page == 'crime' then
        M.render_crime_page(player, frame, content)
    elseif page == 'planets' then
        render_planets_page(player, frame, content)
    elseif page == 'ships' then
        render_ships_page(player, frame, content)
    elseif page == 'players' then
        render_players_page(player, frame, content)
    elseif page == 'player-profile' then
        render_player_profile(player, frame, content)
    elseif page == 'admin' then
        render_admin_page(player, frame, content)
    else
        page = 'help'
        render_help_page(player, frame, content)
    end

    local navigation = frame[NAVIGATION_NAME]
    navigation[NAV_HELP_NAME].enabled = page ~= 'help'
    navigation[NAV_UBI_NAME].enabled = page ~= 'overview'
    navigation.un_nav_market.enabled = page ~= 'market'
    navigation[NAV_PROPERTY_BUILD_NAME].enabled = page ~= 'property-build'
    navigation[NAV_PROPERTY_NAME].enabled = page ~= 'property'
    local crime_navigation = navigation.un_nav_crime
    if crime_navigation and crime_navigation.valid then
        crime_navigation.enabled = page ~= 'crime'
    end
    navigation[NAV_PLANETS_NAME].enabled = page ~= 'planets'
    navigation[NAV_SHIPS_NAME].enabled = page ~= 'ships'
    local admin = navigation[NAV_ADMIN_NAME]
    if admin and admin.valid then admin.enabled = page ~= 'admin' end
end

local function property_error(err)
    if err == 'insufficient-credit' then return {'un.property-error-credit'} end
    if err == 'price-increased' then return {'un.property-error-price-changed'} end
    if err == 'not-owner' then return {'un.property-manage-not-owner'} end
    if err == 'already-owner' then
        return {'un.property-error-ownership'}
    end
    if err == 'in-vehicle' then return {'un.travel-in-vehicle'} end
    if err == 'property-entry-hospice' then
        return {'un.property-enter-disabled-hospice'}
    end
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
    if err == 'feature-disabled' then return {'un.feature-disabled'} end
    if err == 'construction-level-low' then
        return {'un.property-expand-level-required'}
    end
    if err == 'not-expandable' then
        return {'un.property-expand-unavailable'}
    end
    if err == 'lifetime-full' then return {'un.property-renew-full'} end
    if err == 'management-cost-changed' then
        return {'un.property-manage-cost-changed'}
    end
    if err == 'not-inside' then return {'un.property-manage-not-inside'} end
    if err == 'not-player-built' or err == 'permanent' then
        return {'un.property-salvage-unavailable'}
    end
    return {'un.property-error-unavailable'}
end

local function property_disappeared(err)
    return err == 'missing' or err == 'surface-missing'
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
        price.tooltip = {
            'un.property-price-with-change-tooltip',
            property_price_change_caption(property, current_price),
        }
    end

    local can_buy, buy_error = properties.buy_availability(player, property)
    local buy = property_table[property_buy_name(property.id)]
    if buy and buy.valid then
        buy.enabled = can_buy
        buy.tooltip = property_buy_tooltip(
            player, property, can_buy, buy_error
        )
        if buy.tags.action ~= 'property-confirm-buy' then
            buy.caption = property.owner_index == player.index
                and {'un.property-mark-up'} or {'un.property-buy'}
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
        enter.tooltip = property_enter_tooltip(can_enter, enter_error)
    end

end

local function update_ship_actions(player, content)
    local platform, record = ships.of(player.index, factions.of_player(player))
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

local function update_frame(player, shared_faction_statistics)
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
        local stamina_card = content['un_stamina_card']
        local coin_card = content['un_coin_card']
        local experience_card = content['un_experience_card']
        local balance_table = coin_card and coin_card.valid
            and coin_card[BALANCE_TABLE_NAME]
        local balance = balance_table and balance_table.valid
            and balance_table[BALANCE_NAME]
        if balance and balance.valid then
            balance.caption = format_integer(economy.get_balance(player.index))
        end
        local stamina_label = stamina_card and stamina_card.valid
            and stamina_card[STAMINA_NAME]
        if stamina_label and stamina_label.valid then
            stamina_label.caption = {
                'un.stamina-progress',
                format_integer(stamina.get(player.index)),
                format_integer(config.stamina_max),
            }
        end
        local stamina_progress = stamina_card and stamina_card.valid
            and stamina_card['un_stamina_progress']
        if stamina_progress and stamina_progress.valid then
            stamina_progress.value = math.max(0, math.min(
                1, stamina.get(player.index) / config.stamina_max
            ))
        end

        local claimable = economy.get_claimable_ubi(player.index)
        local capacity = economy.get_ubi_capacity()
        local progress = coin_card and coin_card.valid
            and coin_card[UBI_PROGRESS_NAME]
        if progress and progress.valid then
            progress.value = capacity > 0 and claimable / capacity or 0
        end
        local progress_label = coin_card and coin_card.valid
            and coin_card[UBI_PROGRESS_LABEL_NAME]
        if progress_label and progress_label.valid then
            progress_label.caption = {
                'un.ubi-progress',
                format_integer(claimable),
                format_integer(capacity),
            }
        end
        local personal_actions = stamina_card and stamina_card.valid
            and stamina_card.un_personal_actions
        local claim = coin_card and coin_card.valid
            and coin_card[UBI_CLAIM_NAME]
        if claim and claim.valid then
            claim.enabled = claimable > 0
            claim.caption = {
                'un.ubi-claim',
                format_integer(claimable),
                format_integer(capacity),
            }
        end
        local convert = experience_card and experience_card.valid
            and experience_card.un_experience_convert
        if convert and convert.valid then
            convert.enabled = linked_inventory.backpack_science_count(player) > 0
        end
        local kit = personal_actions and personal_actions.valid
            and personal_actions[STARTER_KIT_NAME]
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
        local wood = personal_actions and personal_actions.valid
            and personal_actions[WOOD_SUPPLY_NAME]
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
            update_experience_section(player, content)
        end
    elseif page == 'market' then
        if list_refresh_due(frame, 'market') then
            local amount = M.market_gui.amount(content) or 1
            content.clear()
            M.market_gui.render(
                player,
                frame,
                content,
                amount,
                frame.tags.market_group
            )
        end
    elseif page == 'property-build' then
        update_property_build_page(player, content)
    elseif page == 'planets' then
        update_planet_acceleration_action(player, content)
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
                        or {'un.planet-countdown-clearing'}
                end
                local traits = list[planet_traits_name(item.name)]
                if traits and traits.valid then
                    render_planet_traits(traits, item)
                end
            end
            update_factions_page(player, content, shared_faction_statistics)
        end
    elseif page == 'ships' then
        if list_refresh_due(frame, 'ships') then
            local list_data = ships.list(player.index)
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
        local selected_planet = is_public_planet(frame.tags.property_planet)
            and frame.tags.property_planet or factions.of_player(player)
        local read_only = selected_planet ~= factions.of_player(player)
        if not read_only then
            update_property_renew_action(player, content)
            update_property_expand_action(player, content)
            update_property_salvage_action(player, content)
        end
        local sort_field = property_sort_state(frame)
        local sort_bucket = math.floor(game.tick / config.ticks_per_minute)
        local price_sort_changed = sort_field == 'price'
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
                    selected_planet
                )) do
                    update_property_row(player, property_table, property)
                end
            end
        end
    elseif page == 'crime' then
        update_crime_action(player, content)
        if (frame.tags.property_revision or -1)
                ~= (storage.property_revision or 0)
                or list_refresh_due(frame, 'crime') then
            content.clear()
            M.render_crime_page(player, frame, content)
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
                for _, listed_player in pairs(game.connected_players) do
                    local faction = list[player_element_name('faction', listed_player.index)]
                    local online = list[player_element_name('online', listed_player.index)]
                    local locale = list[player_element_name('locale', listed_player.index)]
                    local coins = list[player_element_name('coins', listed_player.index)]
                    local level = list[player_element_name('level', listed_player.index)]
                    if faction and faction.valid then
                        local planet_name = factions.of_player(listed_player)
                        faction.caption = player_faction_icon(listed_player)
                        faction.tooltip = factions.display_name(planet_name)
                    end
                    if online and online.valid then
                        online.caption = format_hours(playtime.ticks(listed_player))
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
    elseif page == 'player-profile' then
        if list_refresh_due(frame, 'player-profile') then
            content.clear()
            render_player_profile(player, frame, content)
        end
    end
end

local function close_frame(player)
    local frame = player.gui.screen[FRAME_NAME]
    if frame and frame.valid then frame.destroy() end
end

local function apply_frame_width(player, frame)
    if not (player and player.valid and frame and frame.valid) then return end
    local scale = math.max(player.display_scale, 0.1)
    local screen_width = player.display_resolution.width / scale
    local width = math.floor(screen_width * FRAME_WIDTH_FRACTION)
    width = math.max(FRAME_MIN_WIDTH, math.min(FRAME_MAX_WIDTH, width))
    width = math.min(width, math.max(640, math.floor(screen_width - FRAME_SCREEN_MARGIN)))
    frame.style.width = width
end

local function open_frame(player, initial_page)
    close_frame(player)
    local frame = player.gui.screen.add{
        type = 'frame',
        name = FRAME_NAME,
        direction = 'vertical',
    }
    apply_frame_width(player, frame)

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
    navigation.add{type = 'button', name = 'un_nav_market', caption = {'un.page-market'}}
    navigation.add{
        type = 'button',
        name = NAV_PROPERTY_BUILD_NAME,
        caption = {'un.page-property-build'},
    }
    navigation.add{type = 'button', name = NAV_PROPERTY_NAME, caption = {'un.page-property'}}
    if settings.get('crime_enabled') then
        navigation.add{
            type = 'button',
            name = 'un_nav_crime',
            caption = {'un.page-crime'},
        }
    end
    navigation.add{type = 'button', name = NAV_PLANETS_NAME, caption = {'un.page-planets'}}
    navigation.add{type = 'button', name = NAV_SHIPS_NAME, caption = {'un.page-ships'}}
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
local function update_frame_for_display_change(event)
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[FRAME_NAME]
    if not (frame and frame.valid) then return end
    apply_frame_width(player, frame)
    frame.force_auto_center()
end

events.on(
    defines.events.on_player_display_resolution_changed,
    update_frame_for_display_change
)
events.on(
    defines.events.on_player_display_scale_changed,
    update_frame_for_display_change
)
events.on(defines.events.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index)
    if player then
        M.hud_travel.update(player)
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid
                and (frame.tags.page == 'property'
                    or frame.tags.page == 'crime') then
            update_frame(player)
        end
    end
end)
events.on(defines.events.on_player_changed_force, function(event)
    local player = game.get_player(event.player_index)
    if player then
        update_hud_title(player)
        update_hud_reset_countdown(player)
        M.hud_travel.update(player)
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid and frame.tags.page == 'property' then
            update_frame(player)
        end
    end
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
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then
            close_frame(player)
        else
            open_frame(player, 'help')
        end
    elseif element.name == M.hud_travel.name then
        local ok, err = M.hud_travel.cycle(player)
        if not ok then player.print(property_error(err)) end
        M.hud_travel.update(player)
    elseif element.name == CLOSE_NAME then
        close_frame(player)
    elseif element.name == NAV_HELP_NAME then
        render_page(player, 'help')
        update_frame(player)
    elseif element.name == HELP_BRIEF_NAME
            or element.name == HELP_ADVANCED_NAME
            or element.name == HELP_FULL_NAME
            or element.name == HELP_ADMIN_NAME
            or element.name == HELP_STORY_NAME
            or element.name == 'un_help_faction' then
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if not (content and content.valid) then return end
        local mode = element.name == 'un_help_faction' and 'faction'
            or element.name == HELP_STORY_NAME and 'story'
            or element.name == HELP_ADMIN_NAME and 'admin'
            or element.name == HELP_FULL_NAME and 'full'
            or element.name == HELP_ADVANCED_NAME and 'advanced' or 'brief'
        content.clear()
        render_help_page(player, frame, content, mode)
        update_frame(player)
    elseif element.name == NAV_UBI_NAME then
        render_page(player, 'overview')
        update_frame(player)
    elseif element.name == 'un_nav_market' then
        render_page(player, 'market')
        update_frame(player)
    elseif element.name == NAV_PROPERTY_BUILD_NAME then
        render_page(player, 'property-build')
        update_frame(player)
    elseif element.name == NAV_PROPERTY_NAME then
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then
            local tags = frame.tags
            tags.property_planet = factions.of_player(player)
            frame.tags = tags
        end
        render_page(player, 'property')
        update_frame(player)
    elseif element.name == 'un_nav_crime' then
        render_page(player, settings.get('crime_enabled') and 'crime' or 'property')
        update_frame(player)
    elseif element.name == NAV_PLANETS_NAME then
        render_page(player, 'planets')
        update_frame(player)
    elseif element.name == PLANET_ACCELERATE_NAME then
        local ok, err, planet_name = disasters.accelerate_reset(player)
        if not ok then
            player.print({
                'un.planet-reset-accelerate-error-' .. tostring(err),
                config.planet_reset_acceleration_min_remaining_minutes,
                config.planet_reset_acceleration_stamina_cost,
            })
        else
            for _, connected in pairs(game.connected_players) do
                if factions.of_player(connected) == planet_name then
                    update_hud_reset_countdown(connected)
                end
            end
        end
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        if content and content.valid then
            update_planet_acceleration_action(player, content)
            update_frame(player)
        end
    elseif element.name == NAV_SHIPS_NAME then
        render_page(player, 'ships')
        update_frame(player)
    elseif element.name == PLAYER_BROWSE_NAME
            or element.name == PLAYER_PROFILE_BACK_NAME then
        render_page(player, 'players')
        update_frame(player)
    elseif element.name == PLAYER_PROFILE_PERSONAL_NAME then
        render_page(player, 'overview')
        update_frame(player)
    elseif element.tags.action == 'player-view-profile' then
        local target = game.get_player(tonumber(element.tags.target_index))
        if not (target and target.valid) then
            player.print({'un.player-not-found'})
            return
        end
        local frame = player.gui.screen[FRAME_NAME]
        if not (frame and frame.valid) then return end
        local tags = frame.tags
        tags.profile_player_index = target.index
        frame.tags = tags
        render_page(player, 'player-profile')
        update_frame(player)
    elseif element.name == NAV_ADMIN_NAME then
        if player.admin then
            render_page(player, 'admin')
            update_frame(player)
        end
    elseif element.name == UBI_CLAIM_NAME then
        economy.claim_ubi(player.index)
        update_frame(player)
    elseif element.name == 'un_experience_convert' then
        local converted = linked_inventory.convert_backpack(player)
        player.print(converted > 0 and {
            'un.experience-convert-backpack-result',
            format_integer(converted),
        } or {'un.experience-convert-backpack-empty'})
        render_page(player, 'overview')
        update_frame(player)
    elseif element.tags.action and element.tags.action:match('^market%-') then
        local frame = player.gui.screen[FRAME_NAME]
        local content = frame and frame.valid and frame[CONTENT_NAME]
        M.market_gui.handle_click(player, element, frame, content)
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
    elseif element.tags.action == 'ship-view' then
        local ok, err = ships.remote_view(player, element.tags.platform_index)
        if ok then
            close_frame(player)
        else
            player.print(property_error(err))
            render_page(player, 'ships')
            update_frame(player)
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
    elseif element.name:sub(1, #FACTION_SWITCH_PREFIX)
            == FACTION_SWITCH_PREFIX then
        local planet_name = element.tags.planet
        local switch_cost = factions.switch_stamina_cost(planet_name)
        local switch_coin = factions.switch_coin_cost(planet_name)
        if element.tags.action == 'faction-switch-confirm' then
            local ok, err, detail = factions.switch_by_suicide(player, planet_name)
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
                    or err == 'insufficient-credit' and {'un.credit-insufficient'}
                    or err == 'faction-target-location' and {
                        'un.faction-target-location-required',
                        planet_label(planet_name),
                    }
                    or err == 'faction-cooldown' and {
                        'un.faction-switch-cooldown', format_countdown(detail),
                    }
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
                switch_coin,
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
                    switch_coin,
                },
                '\n',
                switch_cost == 0 and {
                    'un.faction-switch-tooltip-free',
                    planet_label(planet_name),
                    config.faction_switch_nauvis_respawn_seconds,
                } or {
                    'un.faction-switch-tooltip',
                    planet_label(planet_name),
                    switch_cost,
                    switch_coin,
                    config.faction_switch_cooldown_hours,
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
        elseif tags.action == 'property-select-planet' then
            if not is_public_planet(tags.planet) then return end
            local frame_tags = frame.tags
            frame_tags.property_planet = tags.planet
            frame.tags = frame_tags
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action and tags.action:match('^admin%-') then
            if not player.admin then
                player.print({'un.admin-only'})
                render_page(player, 'help')
                return
            end
            if DANGEROUS_ADMIN_ACTIONS[tags.action]
                    and frame.tags.admin_dangerous_actions ~= true then
                return
            end
            if tags.action == 'admin-setting-apply' then
                local input = element.parent[admin_setting_input_name(tags.setting)]
                local previous_value = settings.get(tags.setting)
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
                if ok and tags.setting == 'personal_linked_chest_limit' then
                    linked_inventory.enforce_limit()
                end
                if ok and (tags.setting == 'market_base_price_multiplier'
                        or tags.setting == 'market_item_depth_multiplier'
                        or tags.setting == 'market_coin_depth_multiplier') then
                    if not market.apply_admin_settings() then
                        settings.set(tags.setting, previous_value)
                        ok = false
                    end
                end
                player.print(ok and {'un.admin-setting-saved'}
                    or {'un.admin-invalid-value'})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-fill-stamina' then
                stamina.fill(player.index)
                player.print({'un.admin-stamina-filled', config.stamina_max})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-grant-experience' then
                local entries = {}
                for _, pack in ipairs(config.science_pack_order) do
                    entries[#entries + 1] = {
                        name = pack,
                        count = config.admin_experience_grant,
                    }
                end
                experience.record(player.index, entries)
                player.print({'un.admin-experience-granted',
                    config.admin_experience_grant})
            elseif tags.action == 'admin-grant-credit' then
                local ok = economy.change(
                    player.index,
                    config.admin_credit_grant,
                    'admin-test-credit'
                )
                player.print(ok and {
                    'un.admin-credit-granted', config.admin_credit_grant,
                } or {'un.admin-invalid-value'})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-run-automatic-trades' then
                local cottages, trades, items, skipped
                    = properties.process_automatic_trades()
                player.print({
                    'un.admin-automatic-trades-ran',
                    cottages,
                    trades,
                    format_integer(items),
                })
                local reasons = {}
                for reason in pairs(skipped or {}) do
                    reasons[#reasons + 1] = reason
                end
                table.sort(reasons)
                for _, reason in ipairs(reasons) do
                    player.print({
                        'un.admin-automatic-trades-skipped',
                        skipped[reason],
                        {'un.automatic-trade-reason-' .. reason},
                    })
                end
            elseif tags.action == 'admin-diplomacy-friendly'
                    or tags.action == 'admin-diplomacy-hostile' then
                local friendly = tags.action == 'admin-diplomacy-friendly'
                if not tags.confirm then
                    element.caption = friendly
                        and {'un.admin-diplomacy-friendly-confirm'}
                        or {'un.admin-diplomacy-hostile-confirm'}
                    element.tags = {
                        action = tags.action,
                        confirm = true,
                    }
                    return
                end
                factions.set_all_diplomacy(friendly)
                game.print(friendly
                    and {'un.admin-diplomacy-friendly-broadcast'}
                    or {'un.admin-diplomacy-hostile-broadcast'})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-rental-add' then
                if not is_public_planet(tags.planet) then return end
                local property, err = properties.add_rental(tags.planet)
                player.print(property and {
                    'un.admin-rental-added', planet_label(tags.planet),
                } or err == 'property-limit' and {
                    'un.admin-rental-limit', planet_label(tags.planet),
                } or {'un.admin-rental-failed'})
                render_page(player, 'admin')
                update_frame(player)
            elseif tags.action == 'admin-rental-remove' then
                if not is_public_planet(tags.planet) then return end
                local ok, err = properties.remove_rental(tags.planet)
                player.print(ok and {
                    'un.admin-rental-removed', planet_label(tags.planet),
                } or err == 'no-vacant-rental' and {
                    'un.admin-rental-no-vacant', planet_label(tags.planet),
                } or {'un.admin-rental-failed'})
                render_page(player, 'admin')
                update_frame(player)
            end
        elseif tags.action == 'property-build' then
            local form = content[PROPERTY_BUILD_FORM_NAME]
            if not (form and form.valid) then return end
            local planet_name = property_build_planet(player)
            local build_type_index = form[PROPERTY_BUILD_TYPE_NAME].selected_index
            local level_flow = form[PROPERTY_BUILD_LEVEL_FLOW_NAME]
            local level_slider = level_flow and level_flow.valid
                and level_flow[PROPERTY_BUILD_LEVEL_NAME]
            if not (level_slider and level_slider.valid) then return end
            local selected_level = math.floor(level_slider.slider_value + 0.5)
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
                build_type_index,
                selected_level
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
                build_type_index = build_type_index,
                total_level = requirement.total_level,
                custom_name = custom_name or '',
            }
        elseif tags.action == 'property-build-confirm' then
            local property, err = properties.build(
                player,
                tags.planet_name,
                tags.build_type_index,
                tags.custom_name,
                tags.total_level
            )
            player.print(property and {'un.property-built', property.id}
                or property_error(err))
            render_page(player, 'property-build')
            update_frame(player)
        elseif tags.action == 'property-salvage' then
            local property = properties.get(tags.property_id)
            local can_salvage, err, requirement
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
                '[img=item/' .. requirement.pack .. ']',
                format_integer(requirement.experience_refund),
            }
            element.tooltip = {
                'un.property-salvage-confirm-tooltip',
                '[img=item/' .. requirement.pack .. ']',
                format_integer(requirement.experience_refund),
            }
            element.tags = {
                action = 'property-confirm-salvage',
                property_id = property.id,
                quoted_pack = requirement.pack,
                quoted_experience_refund = requirement.experience_refund,
            }
        elseif tags.action == 'property-renew' then
            local property = properties.get(tags.property_id)
            local can_renew, err, requirement
                = properties.renew_availability(player, property)
            if not can_renew then
                if not property_disappeared(err) then
                    player.print(property_error(err))
                end
                render_property_table(player, frame, content)
                update_frame(player)
                return
            end
            element.caption = {
                'un.property-renew-confirm',
                format_integer(requirement.experience_cost),
                format_integer(requirement.stamina_cost),
            }
            element.tags = {
                action = 'property-confirm-renew',
                property_id = property.id,
                quoted_experience_cost = requirement.experience_cost,
                quoted_stamina_cost = requirement.stamina_cost,
            }
        elseif tags.action == 'property-expand' then
            local property = properties.get(tags.property_id)
            local can_expand, err, requirement
                = properties.expansion_availability(player, property)
            if not can_expand then
                if not property_disappeared(err) then
                    player.print(property_error(err))
                end
                render_property_table(player, frame, content)
                update_frame(player)
                return
            end
            element.caption = {
                'un.property-expand-confirm',
                requirement.target_level,
                requirement.width,
                requirement.height,
                format_integer(requirement.experience_cost),
                format_integer(requirement.stamina_cost),
            }
            element.tags = {
                action = 'property-confirm-expand',
                property_id = property.id,
                quoted_experience_cost = requirement.experience_cost,
                quoted_target_level = requirement.target_level,
            }
        elseif tags.action == 'property-buy' then
            local property = properties.get(tags.property_id)
            if not property then
                render_property_table(player, frame, content)
                return
            end
            local quote = properties.current_price(property)
            if property.owner_index == player.index then
                element.caption = {
                    'un.property-confirm-mark-up',
                    format_integer(properties.transaction_tax(
                        property,
                        quote,
                        player.index
                    )),
                }
            else
                element.caption = {
                    'un.property-confirm-buy',
                    format_integer(quote),
                }
            end
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
                tags.quoted_pack,
                tags.quoted_experience_refund
            )
            if not ok and not property_disappeared(err) then
                player.print(property_error(err))
            end
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action == 'property-confirm-renew' then
            local ok, err = properties.renew(
                player,
                tags.property_id,
                tags.quoted_experience_cost,
                tags.quoted_stamina_cost
            )
            if not ok and not property_disappeared(err) then
                player.print(property_error(err))
            end
            render_property_table(player, frame, content)
            update_frame(player)
        elseif tags.action == 'property-confirm-expand' then
            local ok, err = properties.expand(
                player,
                tags.property_id,
                tags.quoted_experience_cost,
                tags.quoted_target_level
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
    if element.name ~= PROPERTY_BUILD_TYPE_NAME then
        return
    end
    local form = content and content.valid and content[PROPERTY_BUILD_FORM_NAME]
    local button = form and form.valid and form[PROPERTY_BUILD_BUTTON_NAME]
    if not (player and button and button.valid) then return end
    button.tags = {action = 'property-build'}
    update_property_build_page(player, content)
end)

events.on(defines.events.on_gui_value_changed, function(event)
    local element = event.element
    if not (element and element.valid
            and element.name == PROPERTY_BUILD_LEVEL_NAME) then return end
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[FRAME_NAME]
    local content = frame and frame.valid and frame[CONTENT_NAME]
    local form = content and content.valid and content[PROPERTY_BUILD_FORM_NAME]
    local button = form and form.valid and form[PROPERTY_BUILD_BUTTON_NAME]
    if not (player and button and button.valid) then return end
    button.tags = {action = 'property-build'}
    update_property_build_page(player, content)
end)

events.on(defines.events.on_gui_text_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    local frame = player and player.gui.screen[FRAME_NAME]
    local content = frame and frame.valid and frame[CONTENT_NAME]
    if not (player and frame and frame.valid and content and content.valid) then
        return
    end
    M.market_gui.handle_text_changed(player, element, frame, content)
end)

events.on(defines.events.on_gui_switch_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local tags = element.tags
    if tags.action == 'ship-visibility' then
        ships.set_public(player.index, element.switch_state == 'right')
        return
    end
    if tags.action == 'admin-dangerous-actions' then
        if not player.admin then
            player.print({'un.admin-only'})
            return
        end
        local frame = player.gui.screen[FRAME_NAME]
        if not (frame and frame.valid and frame.tags.page == 'admin') then
            return
        end
        local frame_tags = frame.tags
        frame_tags.admin_dangerous_actions
            = element.switch_state == 'right'
        frame.tags = frame_tags
        render_page(player, 'admin')
        update_frame(player)
        return
    end
    if tags.action == 'admin-setting-switch' then
        if not player.admin then
            player.print({'un.admin-only'})
            return
        end
        local enabled = element.switch_state == 'right'
        local ok = settings.set(tags.setting, enabled)
        if ok and tags.setting == 'planet_resets_enabled' then
            disasters.apply_enabled(enabled)
            for _, connected in pairs(game.connected_players) do
                update_hud_reset_countdown(connected)
            end
        end
        if ok and tags.setting == 'tech_leak_enabled' then
            technology_decay.apply_enabled(enabled)
        end
        if ok and (tags.setting == 'surface_hidden_from_foreign_factions'
                or tags.setting == 'surface_hidden_from_home_faction') then
            factions.apply_all_surface_visibility()
            ships.ensure()
        end
        if ok and tags.setting == 'crime_enabled' then
            for _, connected in pairs(game.connected_players) do
                local connected_frame = connected.gui.screen[FRAME_NAME]
                if connected_frame and connected_frame.valid then
                    local page = connected_frame.tags.page or 'help'
                    if page == 'crime' and not enabled then page = 'property' end
                    close_frame(connected)
                    open_frame(connected, page)
                end
            end
        elseif ok and (tags.setting == 'property_expansion_enabled'
                or tags.setting == 'property_salvage_enabled') then
            for _, connected in pairs(game.connected_players) do
                local connected_frame = connected.gui.screen[FRAME_NAME]
                if connected_frame and connected_frame.valid
                        and connected_frame.tags.page == 'property' then
                    render_page(connected, 'property')
                    update_frame(connected)
                end
            end
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
        if frame and frame.valid and frame.tags.page == 'overview' then
            update_frame(player)
        end
    end
end)

local PERIODIC_LIST_PAGES = {
    ['property-build'] = true,
    planets = true,
    ships = true,
    property = true,
    crime = true,
    players = true,
    ['player-profile'] = true,
    market = true,
}

scheduler.every(config.gui_list_refresh_ticks, function()
    local shared_faction_statistics = nil
    for _, player in pairs(game.connected_players) do
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid
                and PERIODIC_LIST_PAGES[frame.tags.page] then
            if frame.tags.page == 'planets'
                    and not shared_faction_statistics then
                shared_faction_statistics = collect_faction_statistics()
            end
            update_frame(player, shared_faction_statistics)
        end
    end
end)

scheduler.every(config.ticks_per_minute, function()
    for _, player in pairs(game.connected_players) do
        update_hud_reset_countdown(player)
        M.hud_travel.update(player)
    end
end)

return M
