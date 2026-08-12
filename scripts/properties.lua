local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local experience = require('scripts.experience')
local factions = require('scripts.factions')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local social = require('scripts.social')
local state = require('scripts.state')
local stamina = require('scripts.stamina')
local surfaces = require('scripts.surfaces')

local M = {}

local build_planets = {}
for _, name in ipairs(config.public_planets) do build_planets[name] = true end

local function bump_revision()
    storage.property_revision = (storage.property_revision or 0) + 1
end

local function clear_name_translation_requests(property_id)
    for request_id, request in pairs(
        storage.property_name_translation_requests or {}
    ) do
        if request.property_id == property_id then
            storage.property_name_translation_requests[request_id] = nil
        end
    end
end

local function is_positive_integer(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function is_nonnegative_integer(value)
    return type(value) == 'number' and value >= 0 and value == math.floor(value)
end

function M.normalize_build_name(value)
    if value == nil then return nil, nil end
    if type(value) ~= 'string' then return nil, 'invalid-property-name' end
    if value:find('%c') then return nil, 'invalid-property-name' end
    local name = value:match('^%s*(.-)%s*$') or ''
    if name == '' then return nil, nil end
    if #name > config.property_name_max_bytes then
        return nil, 'invalid-property-name'
    end
    local characters = 0
    for index = 1, #name do
        local byte = name:byte(index)
        if byte < 128 or byte >= 192 then characters = characters + 1 end
    end
    if characters > config.property_name_max_characters then
        return nil, 'invalid-property-name'
    end
    return name, nil
end

local function next_available_property_id()
    local id = 1
    while storage.properties[id]
            or game.surfaces[config.property_surface_prefix .. tostring(id)] do
        id = id + 1
    end
    return id
end

local function next_owner_property_number(owner_index, excluded_property_id)
    local used = {}
    for _, candidate in pairs(storage.properties) do
        if candidate.status == 'active'
                and (not candidate.expires_tick
                    or candidate.expires_tick > game.tick)
                and candidate.owner_index == owner_index
                and candidate.id ~= excluded_property_id
                and is_nonnegative_integer(candidate.owner_property_number) then
            used[candidate.owner_property_number] = true
        end
    end
    local number = 0
    while used[number] do number = number + 1 end
    return number
end

local function assign_owner(property, owner_index)
    if property.owner_index == owner_index then
        if owner_index and not is_nonnegative_integer(
            property.owner_property_number
        ) then
            property.owner_property_number = next_owner_property_number(
                owner_index,
                property.id
            )
        end
        return
    end
    property.owner_index = owner_index
    property.owner_property_number = owner_index
        and next_owner_property_number(owner_index, property.id) or nil
end

local create

local function build_type_by_key(key)
    if type(key) ~= 'string' then return nil end
    for _, build_type in ipairs(config.property_build_types) do
        if build_type.key == key then return build_type end
    end
    return nil
end

local function expansion_size(value, stage)
    local factor = 1 + config.property_expansion_size_per_stage * stage
    return math.floor(value * factor / 2) * 2
end

local function expansion_layout(build_type)
    return {
        fixed_layout = build_type.fixed_layout,
        top_tile = build_type.top_tile,
        top_tile_rows = build_type.top_tile_rows,
        top_split_rows = build_type.top_split_rows,
        top_left_tile = build_type.top_left_tile,
        top_right_tile = build_type.top_right_tile,
    }
end

local function next_planet_property_number(planet_name, excluded_property_id)
    local used = {}
    for _, candidate in pairs(storage.properties) do
        if candidate.status == 'active'
                and candidate.permanent
                and candidate.sample_planet == planet_name
                and candidate.id ~= excluded_property_id
                and is_positive_integer(candidate.planet_property_number) then
            used[candidate.planet_property_number] = true
        end
    end
    local number = 1
    while used[number] do number = number + 1 end
    return number
end

function M.display_name(property)
    if property.custom_name then return property.custom_name end
    if not property.owner_index then
        if property.sample_planet then
            return {
                '',
                '[img=space-location/' .. property.sample_planet .. '] ',
                {
                    'un.property-surface-vacant',
                    property.planet_property_number or property.id,
                },
            }
        end
        return {'un.property-surface-vacant', property.id}
    end
    local owner = game.get_player(property.owner_index)
    local account = storage.players[property.owner_index]
    local owner_name = owner and owner.name
        or account and account.name
        or ('#' .. property.owner_index)
    local number = property.owner_property_number
    local suffix = is_nonnegative_integer(number) and number > 0
        and (' ' .. tostring(number)) or ''
    return {
        '',
        '[img=space-location/' .. property.sample_planet .. '] ',
        {'un.property-surface-owned', owner_name, suffix},
    }
end

local function property_name_position(property)
    local height = property.height or property.size or 0
    return {x = 0, y = -height / 2 - 4}
end

local function ensure_property_name_rendering(property, text)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
    local object = property.name_render_id
        and rendering.get_object_by_id(property.name_render_id)
    if object and object.valid then
        object.text = text
        object.target = property_name_position(property)
        return true
    end
    object = rendering.draw_text{
        text = text,
        surface = surface,
        target = property_name_position(property),
        color = {r = 0.35, g = 0.8, b = 1},
        font = 'default-large-bold',
        alignment = 'center',
        vertical_alignment = 'bottom',
        scale = 2,
        scale_with_zoom = true,
    }
    property.name_render_id = object.id
    return true
end

local function property_rendering_fallback(property)
    if type(property.custom_name) == 'string' then return property.custom_name end
    return '#' .. tostring(property.id)
end

local function first_connected_player()
    local selected = nil
    for _, player in pairs(game.connected_players) do
        if not selected or player.index < selected.index then selected = player end
    end
    return selected
end

local function request_property_name_translation(property, player)
    if type(property.custom_name) == 'string' then
        return ensure_property_name_rendering(property, property.custom_name)
    end
    if not (player and player.valid and player.connected) then return false end
    local request_id = player.request_translation(M.display_name(property))
    if not request_id then return false end
    storage.property_name_translation_requests[request_id] = {
        property_id = property.id,
        player_index = player.index,
        owner_token = property.owner_index or 0,
        owner_property_number = property.owner_property_number or 0,
        created_tick = property.created_tick,
    }
    return true
end

function M.feature_description(property)
    local width = property.width or property.size or 0
    local height = property.height or property.size or 0
    local dimensions = {
        'un.property-features',
        width,
        height,
    }
    local multiplier = tonumber(property.crime_chance_multiplier)
    if not multiplier or multiplier == 1 then return dimensions end
    return {
        '',
        dimensions,
        '\n',
        {'un.property-feature-crime-multiplier', multiplier * 100},
    }
end

function M.surface_display_name(property)
    return M.display_name(property)
end

local function central_chest_positions()
    return {
        {x = -0.5, y = -0.5},
        {x = 0.5, y = -0.5},
        {x = -0.5, y = 0.5},
        {x = 0.5, y = 0.5},
    }
end

local function position_key(position)
    return tostring(position.x) .. ',' .. tostring(position.y)
end

local function normalize_linked_chest_positions(property, surface)
    local target = central_chest_positions()
    local target_keys = {}
    for _, position in ipairs(target) do
        target_keys[position_key(position)] = true
    end

    for _, position in ipairs(property.linked_chest_positions or {}) do
        if not target_keys[position_key(position)] then
            local chest = surface.find_entity(config.linked_chest_name, position)
            if chest and chest.valid then chest.destroy() end
        end
    end

    property.linked_chest_positions = target
    property.linked_chest_count = nil
end

local function ensure_linked_chests(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
    surface.localised_name = M.surface_display_name(property)
    property.min_brightness = config.property_min_brightness
    surfaces.sync_property_environment(
        surface,
        property.min_brightness,
        property.terrain_planet or property.sample_planet
    )
    property.solar = surface.solar_power_multiplier
    normalize_linked_chest_positions(property, surface)
    local force = factions.of_planet(property.sample_planet)
    if not (force and force.valid) then return false end
    local link_id = property.owner_index or config.property_link_id_unowned
    for _, position in ipairs(property.linked_chest_positions) do
        local chest = surface.find_entity(config.linked_chest_name, position)
        if not (chest and chest.valid) then
            chest = surface.create_entity{
                name = config.linked_chest_name,
                position = position,
                force = force,
                raise_built = false,
            }
        end
        if not (chest and chest.valid) then return false end
        chest.link_id = link_id
        chest.operable = false
        chest.destructible = false
        -- LuaEntity::minable became read-only in Factorio 2.1. The mutable
        -- script flag is available in both 2.0 and 2.1.
        chest.minable_flag = false
    end
    return true
end

local function sync_surface_visibility(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
    return factions.reveal_surface_to_factions(surface)
end

create = function(spec)
    state.ensure()
    spec = spec or {}
    local custom_name, name_err = M.normalize_build_name(spec.custom_name)
    if name_err then return nil, name_err end
    local price
    if spec.price == nil then
        price = math.random(
            config.property_initial_price_min,
            config.property_initial_price_max
        )
    else
        price = math.floor(tonumber(spec.price) or 0)
    end
    local tax = tonumber(spec.tax) or settings.get('property_tax_percent') / 100
    local width = tonumber(spec.width)
    local height = tonumber(spec.height)
    if not is_positive_integer(price) or price > config.property_price_cap then
        return nil, 'invalid-price'
    end
    if not is_positive_integer(width) or not is_positive_integer(height) then
        return nil, 'invalid-size'
    end
    if width > config.property_max_size
            or height > config.property_max_size then
        return nil, 'invalid-size'
    end
    if not build_planets[spec.sample_planet] then return nil, 'invalid-planet' end
    local permanent = spec.permanent == true
    local lifetime_hours = tonumber(spec.lifetime_hours)
    if not permanent and (not lifetime_hours or lifetime_hours <= 0) then
        return nil, 'invalid-lifetime'
    end
    local decay_hours = tonumber(spec.decay_hours)
    if not decay_hours or decay_hours <= 0 then return nil, 'invalid-decay' end
    if tax < 0 or tax > 1 then return nil, 'invalid-tax' end

    local expires_tick = nil
    if not permanent then
        expires_tick = game.tick + lifetime_hours * config.ticks_per_hour
    end

    local build_type = build_type_by_key(spec.construction_type)
    local expansion_stages = build_type and build_type.expandable
        and config.property_expansion_stages or 0
    local max_width = width
    local max_height = height
    if expansion_stages > 0 then
        max_width = math.min(
            config.property_max_size,
            expansion_size(width, expansion_stages)
        )
        max_height = math.min(
            config.property_max_size,
            expansion_size(height, expansion_stages)
        )
        if max_width <= width or max_height <= height then
            expansion_stages = 0
            max_width = width
            max_height = height
        end
    end

    local id = next_available_property_id()
    local min_brightness = config.property_min_brightness
    local surface, half_width, half_height, terrain_planet, sample_position
        = surfaces.create_property_surface(id, {
        width = width,
        height = height,
        surface_width = max_width,
        surface_height = max_height,
        sample_planet = spec.sample_planet,
        terrain_planet = spec.terrain_planet,
        fixed_layout = spec.fixed_layout,
        top_tile = spec.top_tile,
        top_tile_rows = spec.top_tile_rows,
        top_split_rows = spec.top_split_rows,
        top_left_tile = spec.top_left_tile,
        top_right_tile = spec.top_right_tile,
    })
    if not surface then return nil, 'surface-create-failed' end
    storage.next_property_id = id + 1
    local property = {
        id = id,
        custom_name = custom_name,
        surface_name = surface.name,
        surface_index = surface.index,
        status = 'active',
        owner_index = nil,
        owner_property_number = nil,
        base_price = price,
        price_at_tick = game.tick,
        decay_ticks = decay_hours * config.ticks_per_hour,
        tax = tax,
        width = width,
        height = height,
        base_width = width,
        base_height = height,
        max_width = max_width,
        max_height = max_height,
        expansion_stage = 0,
        expansion_stages = expansion_stages,
        solar = surface.solar_power_multiplier,
        min_brightness = min_brightness,
        sample_planet = spec.sample_planet,
        terrain_planet = terrain_planet,
        sample_position = sample_position,
        linked_chest_positions = central_chest_positions(),
        created_tick = game.tick,
        expires_tick = expires_tick,
        lifetime_hours = lifetime_hours,
        permanent = permanent,
        rental = spec.rental == true,
        construction_value = tonumber(spec.construction_value),
        construction_type = type(spec.construction_type) == 'string'
            and spec.construction_type or nil,
        construction_level = tonumber(spec.construction_level),
        crime_chance_multiplier = tonumber(spec.crime_chance_multiplier),
        planet_property_number = permanent
            and next_planet_property_number(spec.sample_planet, id) or nil,
        system_key = spec.system_key,
    }
    assign_owner(property, spec.owner_index)
    storage.properties[id] = property
    sync_surface_visibility(property)
    ensure_property_name_rendering(property, property_rendering_fallback(property))
    local translator = property.owner_index
        and game.get_player(property.owner_index) or first_connected_player()
    if translator then request_property_name_translation(property, translator) end
    if not ensure_linked_chests(property) then
        log('[un] failed to create property linked chests for property ' .. id)
    end
    bump_revision()
    return property
end

local function create_permanent_defaults()
    local complete = true
    local created = 0
    for _, planet_name in ipairs(config.public_planets) do
        local defaults = config.property_permanent_defaults_by_planet
            and config.property_permanent_defaults_by_planet[planet_name] or {}
        for tier_index, spec in ipairs(defaults) do
            for slot = 1, spec.count do
                local key = table.concat({planet_name, tier_index, slot}, ':')
                local existing = false
                for _, property in pairs(storage.properties) do
                    if property.status == 'active'
                            and property.system_key == key then
                        existing = true
                        break
                    end
                end
                if not existing then
                    local property, err = create{
                        sample_planet = planet_name,
                        terrain_planet = spec.terrain_planet,
                        width = spec.width,
                        height = spec.height,
                        decay_hours = spec.decay_hours,
                        fixed_layout = spec.fixed_layout,
                        permanent = true,
                        rental = true,
                        system_key = key,
                    }
                    if property then
                        created = created + 1
                    else
                        complete = false
                        log('[un] failed to create permanent property '
                            .. key .. ': ' .. tostring(err))
                    end
                end
            end
        end
    end
    storage.permanent_properties_created = complete
    return created, complete
end

function M.ensure()
    state.ensure()
    if not storage.permanent_properties_created then
        create_permanent_defaults()
    end
    for _, property in ipairs(M.list()) do
        sync_surface_visibility(property)
        ensure_linked_chests(property)
        ensure_property_name_rendering(
            property,
            property.rendered_name or property_rendering_fallback(property)
        )
        if property.owner_index then
            request_property_name_translation(
                property,
                game.get_player(property.owner_index)
            )
        else
            local translator = first_connected_player()
            if translator then request_property_name_translation(property, translator) end
        end
    end
end

function M.get(property_id)
    state.ensure()
    local property = storage.properties[tonumber(property_id)]
    if property and property.status == 'active'
            and (not property.expires_tick or property.expires_tick > game.tick) then
        return property
    end
    return nil
end

function M.list(planet_name)
    state.ensure()
    local result = {}
    for _, property in pairs(storage.properties) do
        if property.status == 'active'
                and (not property.expires_tick or property.expires_tick > game.tick)
                and (not planet_name or property.sample_planet == planet_name) then
            result[#result + 1] = property
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

function M.left_ticks(property)
    if not property or not property.expires_tick then return nil end
    return math.max(0, property.expires_tick - game.tick)
end

function M.build_requirements(player, planet_name, build_type_index, selected_level)
    local build_type = config.property_build_types[tonumber(build_type_index)]
    if not (player and player.valid and build_planets[planet_name]
            and build_type) then
        return nil
    end
    local current_level = experience.total_level(player.index)
    local level = selected_level == nil
        and current_level or tonumber(selected_level)
    if not level or level ~= math.floor(level)
            or level < 0 or level > current_level then
        return nil
    end
    local raw_width = build_type.base_width
        + (build_type.width_per_level or 1) * level
    local width = build_type.exact_dimensions and math.floor(raw_width)
        or math.floor(raw_width / 2) * 2
    width = math.min(build_type.max_width, width)
    local raw_height = build_type.height
        + (build_type.height_per_level or 0) * level
    local height = build_type.exact_dimensions and math.floor(raw_height)
        or math.floor(raw_height / 2) * 2
    height = math.min(build_type.max_height, height)
    local experience_cost = config.property_build_experience_base
        + config.property_build_experience_per_level * level
    local initial_price = math.min(
        config.property_price_cap,
        math.ceil(experience_cost
            * settings.get('property_build_price_multiplier')
            * (build_type.initial_price_multiplier or 1))
    )
    return {
        planet_name = planet_name,
        build_type_index = tonumber(build_type_index),
        build_type = build_type,
        pack = build_type.pack,
        total_level = level,
        current_total_level = current_level,
        lifetime = {
            hours = build_type.base_lifetime_hours
                + build_type.lifetime_hours_per_level * level,
            decay_hours = build_type.base_decay_hours
                + build_type.decay_hours_per_level * level,
        },
        size = {width = width, height = height},
        experience_cost = experience_cost,
        initial_price = initial_price,
        stamina_cost = config.property_build_stamina_cost,
    }
end

function M.build_availability(player, planet_name, build_type_index, selected_level)
    local requirement = M.build_requirements(
        player, planet_name, build_type_index, selected_level
    )
    if not requirement then return false, 'invalid-build-option' end
    if factions.of_player(player) ~= planet_name then
        return false, 'wrong-faction', requirement
    end
    if #M.list(planet_name) >= settings.get('property_limit_per_planet') then
        return false, 'property-limit', requirement
    end
    if not surfaces.is_public_planet_open(planet_name) then
        return false, 'planet-closed', requirement
    end
    if experience.amount(player.index, requirement.pack)
            < requirement.experience_cost then
        return false, 'insufficient-experience', requirement
    end
    if stamina.get(player.index) < requirement.stamina_cost then
        return false, 'insufficient-stamina', requirement
    end
    return true, nil, requirement
end

function M.build(player, planet_name, build_type_index, custom_name, expected_level)
    local normalized_name, name_err = M.normalize_build_name(custom_name)
    if name_err then return nil, name_err end
    local available, err, requirement = M.build_availability(
        player,
        planet_name,
        build_type_index,
        expected_level
    )
    if not available then return nil, err, requirement end
    if not experience.spend(
        player.index,
        requirement.pack,
        requirement.experience_cost
    ) then
        return nil, 'insufficient-experience', requirement
    end
    if not stamina.spend(player.index, requirement.stamina_cost) then
        experience.record(player.index, {{
            name = requirement.pack,
            count = requirement.experience_cost,
        }})
        return nil, 'insufficient-stamina', requirement
    end
    local ok, property, create_err = pcall(create, {
        owner_index = player.index,
        sample_planet = planet_name,
        terrain_planet = requirement.build_type.terrain_planet,
        fixed_layout = requirement.build_type.fixed_layout,
        top_tile = requirement.build_type.top_tile,
        top_tile_rows = requirement.build_type.top_tile_rows,
        top_split_rows = requirement.build_type.top_split_rows,
        top_left_tile = requirement.build_type.top_left_tile,
        top_right_tile = requirement.build_type.top_right_tile,
        price = requirement.initial_price,
        lifetime_hours = requirement.lifetime.hours,
        decay_hours = requirement.lifetime.decay_hours,
        width = requirement.size.width,
        height = requirement.size.height,
        custom_name = normalized_name,
        construction_value = requirement.initial_price,
        construction_type = requirement.build_type.key,
        construction_level = requirement.total_level,
        crime_chance_multiplier = requirement.build_type.crime_chance_multiplier,
    })
    if not ok or not property then
        experience.record(player.index, {{
            name = requirement.pack,
            count = requirement.experience_cost,
        }})
        stamina.refund(player.index, requirement.stamina_cost)
        if not ok then
            log('[un] property construction failed: ' .. tostring(property))
            create_err = 'surface-create-failed'
        end
        return nil, create_err, requirement
    end
    game.print({
        'un.property-built-broadcast',
        player.name,
        M.display_name(property),
        {'', '[img=space-location/' .. planet_name .. '] ',
            {'space-location-name.' .. planet_name}},
        requirement.experience_cost,
        requirement.stamina_cost,
        factions.display_name(planet_name),
    })
    return property, nil, requirement
end

function M.current_price(property, tick)
    tick = tick or game.tick
    local exponent = (property.price_at_tick - tick) / property.decay_ticks
    local raw = property.base_price
        * (settings.get('property_price_factor') ^ exponent)
    if raw >= config.property_price_cap then return config.property_price_cap end
    if raw <= 1 then return 1 end
    return math.ceil(raw)
end

function M.transaction_tax_rate(property, buyer_index)
    local level = property.owner_index
        and experience.total_level(property.owner_index) or 0
    local rate = property.tax / (level / 100 + 1)
    if property.owner_index and property.owner_index == buyer_index then
        rate = rate * settings.get('property_self_purchase_tax_multiplier')
    end
    return rate
end

function M.transaction_tax(property, price, buyer_index)
    if not property.owner_index then return price end
    local payout = math.floor(
        price * (1 - M.transaction_tax_rate(property, buyer_index))
    )
    return price - payout
end

function M.owner_name(property)
    if not property.owner_index then return nil end
    local player = game.get_player(property.owner_index)
    if player then return player.name end
    local account = storage.players[property.owner_index]
    return account and account.name or ('#' .. property.owner_index)
end

function M.all_open(player_index)
    if not player_index then return false end
    return economy.ensure_account(player_index).all_properties_open == true
end

function M.set_all_open(player_index, enabled)
    local account = economy.ensure_account(player_index)
    local value = enabled == true
    if account.all_properties_open == value then return false end
    account.all_properties_open = value
    bump_revision()
    return true
end

function M.owned_count(player_index, planet_name)
    local count = 0
    for _, property in ipairs(M.list(planet_name)) do
        if property.owner_index == player_index then count = count + 1 end
    end
    return count
end

local function property_on_surface(surface)
    if not (surface and surface.valid) then return nil end
    local prefix = config.property_surface_prefix
    if surface.name:sub(1, #prefix) ~= prefix then return nil end
    local property = M.get(tonumber(surface.name:sub(#prefix + 1)))
    if property and property.surface_index == surface.index then return property end
    return nil
end


function M.property_at_player(player)
    return player and property_on_surface(player.physical_surface) or nil
end

local function home_travel_context(player)
    if not (player and player.valid) then return nil, nil, 'invalid-player' end
    if player.vehicle and player.vehicle.valid then return nil, nil, 'in-vehicle' end
    local planet_name = factions.of_player(player)
    if not planet_name then return nil, nil, 'wrong-faction' end
    local surface = player.physical_surface
    if not (surface and surface.valid) then
        return nil, nil, 'travel-restricted'
    end
    if surface.name == planet_name then return 'planet', planet_name end
    if surfaces.hospice_planet(surface) == planet_name then
        return 'hospice', planet_name
    end
    local property = property_on_surface(surface)
    if property and property.sample_planet == planet_name then
        return 'property', planet_name, nil, property
    end
    return nil, planet_name, 'travel-restricted'
end

local function owned_homes(player_index, planet_name)
    local result = {}
    for _, property in ipairs(M.list(planet_name)) do
        if property.owner_index == player_index then
            result[#result + 1] = property
        end
    end
    table.sort(result, function(a, b)
        local a_number = tonumber(a.owner_property_number) or math.huge
        local b_number = tonumber(b.owner_property_number) or math.huge
        if a_number ~= b_number then return a_number < b_number end
        return a.id < b.id
    end)
    return result
end

function M.home_shuttle_availability(player)
    local context, planet_name, err = home_travel_context(player)
    if not context then return false, err, context, planet_name end
    if context ~= 'planet' and not surfaces.is_public_planet_open(planet_name) then
        return false, 'planet-closed', context, planet_name
    end
    return true, nil, context, planet_name
end

function M.owned_property_travel_availability(player)
    local context, planet_name, err = home_travel_context(player)
    if not context then return false, err, 0 end
    local homes = owned_homes(player.index, planet_name)
    if #homes == 0 then return false, 'no-owned-property', 0 end
    return true, nil, #homes
end

function M.hospice_travel_availability(player)
    local context, planet_name, err = home_travel_context(player)
    if not context then return false, err end
    return true, nil, planet_name
end

local function remember_public_departure(
        player,
        planet_name,
        source_surface,
        source_position
    )
    if not (source_surface and source_surface.valid
            and source_surface.name == planet_name
            and source_position) then
        return
    end
    local reset = storage.public_planet_resets
        and storage.public_planet_resets[planet_name]
    local account = economy.ensure_account(player.index)
    account.last_public_position_by_planet
        = account.last_public_position_by_planet or {}
    account.last_public_position_by_planet[planet_name] = {
        position = {x = source_position.x, y = source_position.y},
        surface_index = source_surface.index,
        round = reset and reset.round or 0,
    }
end

local function travel_to_hospice_recording(player, planet_name)
    local source_surface = player.physical_surface
    local source_position = player.physical_position
    local ok, err = surfaces.to_hospice(player, planet_name)
    if ok then
        remember_public_departure(
            player,
            planet_name,
            source_surface,
            source_position
        )
    end
    return ok, err
end

function M.travel_to_hospice(player)
    local available, err, planet_name = M.hospice_travel_availability(player)
    if not available then return false, err end
    return travel_to_hospice_recording(player, planet_name)
end

local function release_property(property)
    assign_owner(property, nil)
    property.planet_property_number = next_planet_property_number(
        property.sample_planet,
        property.id
    )
    property.owner_cleanup_tick = game.tick
    ensure_linked_chests(property)
    sync_surface_visibility(property)
    local translator = first_connected_player()
    if translator then request_property_name_translation(property, translator) end
end

function M.release_owner(player_index)
    state.ensure()
    local changed = 0
    for _, property in ipairs(M.list()) do
        if property.owner_index == player_index then
            release_property(property)
            changed = changed + 1
        end
    end
    if changed > 0 then bump_revision() end
    return changed
end

function M.release_owner_in_faction(player_index, planet_name)
    state.ensure()
    local changed = 0
    for _, property in ipairs(M.list(planet_name)) do
        if property.owner_index == player_index then
            release_property(property)
            changed = changed + 1
        end
    end
    if changed > 0 then bump_revision() end
    return changed
end

local function valid_surface(property)
    local surface = property and game.surfaces[property.surface_name]
    return surface and surface.valid or false
end

function M.buy_availability(player, property)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    if factions.of_player(player) ~= property.sample_planet then
        return false, 'wrong-faction'
    end
    local price = M.current_price(property)
    local required = property.owner_index == player.index
        and M.transaction_tax(property, price, player.index) or price
    if economy.get_balance(player.index) < required then
        return false, 'insufficient-credit'
    end
    return true
end

function M.enter_availability(player, property)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    local context, planet_name, travel_err = home_travel_context(player)
    if not context then return false, travel_err end
    if factions.of_player(player) ~= property.sample_planet then
        return false, 'wrong-faction'
    end
    if planet_name ~= property.sample_planet then return false, 'wrong-faction' end
    if player.admin and settings.get('admin_property_access') then return true end
    if property.owner_index == player.index then return true end
    if M.all_open(property.owner_index) then return true end
    if social.are_mutual(player.index, property.owner_index) then return true end
    return false, 'not-owner'
end

function M.buy(player, property_id, quoted_price)
    local property = M.get(property_id)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    if factions.of_player(player) ~= property.sample_planet then
        return false, 'wrong-faction'
    end
    local price = M.current_price(property)
    local self_purchase = property.owner_index == player.index
    local seller_name = M.owner_name(property)
    local transaction_name = M.display_name(property)
    if quoted_price and price > quoted_price then return false, 'price-increased', price end
    local payout = property.owner_index
        and math.floor(price * (1
            - M.transaction_tax_rate(property, player.index))) or 0
    local tax = price - payout
    local ok, err = economy.taxed_transfer(
        player.index,
        property.owner_index,
        price,
        payout,
        'property-purchase'
    )
    if not ok then return false, err end

    assign_owner(property, player.index)
    sync_surface_visibility(property)
    property.base_price = price
    property.price_at_tick = game.tick + property.decay_ticks
    property.purchased_tick = game.tick
    property.purchase_price = price
    request_property_name_translation(property, player)
    if not ensure_linked_chests(property) then
        log('[un] property relink failed for property ' .. property.id)
    end
    bump_revision()
    if self_purchase then
        game.print({
            'un.property-mark-up-broadcast',
            player.name,
            transaction_name,
            price,
            tax,
            factions.display_name(property.sample_planet),
        })
    elseif seller_name then
        game.print({
            'un.property-purchase-player-broadcast',
            player.name,
            price,
            seller_name,
            transaction_name,
            payout,
            tax,
            factions.display_name(property.sample_planet),
        })
    else
        game.print({
            'un.property-purchase-vacant-broadcast',
            player.name,
            price,
            transaction_name,
            price,
            factions.display_name(property.sample_planet),
        })
    end
    return true, price
end

function M.enter(player, property_id)
    local property = M.get(property_id)
    if not property then return false, 'missing' end
    local allowed, availability_error = M.enter_availability(player, property)
    if not allowed then return false, availability_error end
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    local source = player.physical_surface
    local source_position = player.physical_position
    local ok, err
    if player.admin and settings.get('admin_property_access') then
        ok, err = surfaces.teleport_near(player, surface, {0, 0}, false)
    else
        ok, err = surfaces.teleport(player, surface)
    end
    if ok then
        remember_public_departure(
            player,
            property.sample_planet,
            source,
            source_position
        )
        if property.owner_index == player.index then
            local account = economy.ensure_account(player.index)
            account.last_property_id = property.id
            account.last_property_by_planet
                = account.last_property_by_planet or {}
            account.last_property_by_planet[property.sample_planet] = property.id
        end
    end
    return ok, err
end

local function owned_home(player_index, planet_name)
    local account = economy.ensure_account(player_index)
    account.last_property_by_planet = account.last_property_by_planet or {}
    local property = M.get(account.last_property_by_planet[planet_name])
    if property and property.owner_index == player_index
            and property.sample_planet == planet_name then
        return property
    end
    account.last_property_by_planet[planet_name] = nil
    for _, candidate in ipairs(M.list(planet_name)) do
        if candidate.owner_index == player_index then return candidate end
    end
    return nil
end

function M.home_shuttle(player)
    local available, err, context, planet_name
        = M.home_shuttle_availability(player)
    if not available then return false, err end
    if context == 'planet' then
        return travel_to_hospice_recording(player, planet_name)
    end
    local account = economy.ensure_account(player.index)
    local positions = account.last_public_position_by_planet or {}
    return surfaces.to_planet_origin(player, planet_name, positions[planet_name])
end

function M.travel_to_owned_property(player)
    local available, err = M.owned_property_travel_availability(player)
    if not available then return false, err end
    local context, planet_name, _, current = home_travel_context(player)
    if not context then return false, 'travel-restricted' end
    local homes = owned_homes(player.index, planet_name)
    local target
    if current and current.owner_index == player.index then
        for index, property in ipairs(homes) do
            if property.id == current.id then
                target = homes[index % #homes + 1]
                break
            end
        end
    end
    target = target or owned_home(player.index, planet_name) or homes[1]
    return M.enter(player, target.id)
end

local function evacuate_property(property, surface)
    local hospice = surfaces.hospice_surface(property.sample_planet)
    for _, player in pairs(game.players) do
        if player.controller_type == defines.controllers.remote
                and player.surface == surface then
            pcall(function() player.exit_remote_view() end)
            if player.controller_type == defines.controllers.remote
                    and player.surface == surface then
                pcall(function()
                    player.set_controller{
                        type = defines.controllers.remote,
                        surface = hospice,
                        position = {0, 0},
                    }
                end)
            end
        end
        if player.physical_surface == surface then
            pcall(function()
                if player.connected then player.exit_remote_view() end
                if player.vehicle and player.vehicle.valid then
                    player.driving = false
                end
                local moved = surfaces.teleport_near(
                    player,
                    hospice,
                    {0, 0},
                    true
                )
                if not moved then player.teleport({0, 2}, hospice) end
            end)
        end
        for _, character in pairs(player.get_associated_characters()) do
            if character.valid and character.surface == surface then
                pcall(function() character.teleport({0, 2}, hospice) end)
            end
        end
    end
end

local function delete_property_surface(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    evacuate_property(property, surface)
    property.status = 'deleting'
    storage.deleting_properties[surface.index] = property.id
    if game.delete_surface(surface) then
        bump_revision()
        return true
    end
    storage.deleting_properties[surface.index] = nil
    property.status = 'active'
    return false, 'surface-delete-failed'
end

function M.rental_counts(planet_name)
    if not build_planets[planet_name] then return 0, 0 end
    local total = 0
    local vacant = 0
    for _, property in ipairs(M.list(planet_name)) do
        if property.rental == true then
            total = total + 1
            if not property.owner_index then vacant = vacant + 1 end
        end
    end
    return total, vacant
end

function M.add_rental(planet_name)
    if not build_planets[planet_name] then return nil, 'invalid-planet' end
    if #M.list(planet_name) >= settings.get('property_limit_per_planet') then
        return nil, 'property-limit'
    end
    return create{
        sample_planet = planet_name,
        width = settings.get('rental_property_width'),
        height = settings.get('rental_property_height'),
        decay_hours = config.rental_property_decay_hours,
        fixed_layout = {fill_tile = 'tutorial-grid'},
        permanent = true,
        rental = true,
    }
end

function M.remove_rental(planet_name)
    if not build_planets[planet_name] then return false, 'invalid-planet' end
    local target = nil
    for _, property in ipairs(M.list(planet_name)) do
        if property.rental == true and not property.owner_index
                and (not target
                    or (property.planet_property_number or 0)
                        > (target.planet_property_number or 0)
                    or property.planet_property_number
                        == target.planet_property_number
                        and property.id > target.id) then
            target = property
        end
    end
    if not target then return false, 'no-vacant-rental' end
    local surface = game.surfaces[target.surface_name]
    if surface and surface.valid then return delete_property_surface(target) end
    clear_name_translation_requests(target.id)
    storage.properties[target.id] = nil
    bump_revision()
    return true
end

function M.reset_permanent_defaults()
    state.ensure()
    local permanent = {}
    for _, property in pairs(storage.properties) do
        if property.permanent and property.status == 'active' then
            permanent[#permanent + 1] = property
        end
    end
    table.sort(permanent, function(a, b) return a.id < b.id end)

    local removed = 0
    local failed = 0
    for _, property in ipairs(permanent) do
        local surface = game.surfaces[property.surface_name]
        if surface and surface.valid then
            local ok = delete_property_surface(property)
            if ok then removed = removed + 1 else failed = failed + 1 end
        else
            clear_name_translation_requests(property.id)
            storage.properties[property.id] = nil
            removed = removed + 1
            bump_revision()
        end
    end

    storage.permanent_properties_created = false
    local created, complete = create_permanent_defaults()
    return {
        removed = removed,
        failed = failed,
        created = created,
        complete = complete and failed == 0,
    }
end

remote.add_interface('un_properties', {
    reset_permanent_defaults = M.reset_permanent_defaults,
})

-- Account cleanup removes player-built property surfaces without a salvage
-- payout. Permanent public properties survive and return to the vacant pool.
function M.remove_owner_assets(player_index)
    state.ensure()
    local owned = {}
    for _, property in pairs(storage.properties) do
        if property.status == 'active'
                and property.owner_index == player_index then
            owned[#owned + 1] = property
        end
    end
    table.sort(owned, function(a, b) return a.id < b.id end)

    local removed = 0
    local released = 0
    for _, property in ipairs(owned) do
        if property.permanent then
            release_property(property)
            released = released + 1
        else
            local surface = game.surfaces[property.surface_name]
            if not (surface and surface.valid) then
                clear_name_translation_requests(property.id)
                storage.properties[property.id] = nil
                bump_revision()
                removed = removed + 1
            else
                local ok, err = delete_property_surface(property)
                if ok then
                    removed = removed + 1
                else
                    -- Never retain ownership under an index that the engine is
                    -- about to delete. The lifecycle pass will retry deletion.
                    release_property(property)
                    property.expires_tick = game.tick
                    log('[un] deferred property cleanup ' .. property.id
                        .. ': ' .. tostring(err))
                end
            end
        end
    end
    if released > 0 then bump_revision() end
    return removed, released
end

function M.clear_player_translation_requests(player_index)
    state.ensure()
    for request_id, request in pairs(storage.property_name_translation_requests) do
        if request.player_index == player_index
                or request.owner_index == player_index then
            storage.property_name_translation_requests[request_id] = nil
        end
    end
end

function M.salvage_value(property)
    if not property or property.permanent then return nil end
    local construction_value = tonumber(property.construction_value)
    local created_tick = tonumber(property.created_tick)
    local expires_tick = tonumber(property.expires_tick)
    if not construction_value or construction_value <= 0
            or not created_tick or not expires_tick
            or expires_tick <= created_tick then
        return nil
    end
    local remaining_ticks = math.max(0, expires_tick - game.tick)
    if remaining_ticks <= 0 then return nil end
    local value = math.floor(
        construction_value
            * settings.get('property_salvage_percent') / 100
            * remaining_ticks / (expires_tick - created_tick)
    )
    return math.max(1, value)
end

function M.salvage_availability(player, property)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    if not (player.physical_surface
            and player.physical_surface.index == property.surface_index) then
        return false, 'not-inside'
    end
    if property.owner_index ~= player.index then return false, 'not-owner' end
    if property.permanent then return false, 'permanent' end
    local value = M.salvage_value(property)
    if not value then return false, 'not-player-built' end
    return true, nil, value
end

function M.salvage_at_player_availability(player)
    state.ensure()
    local surface = player and player.physical_surface
    if not (surface and surface.valid) then return false, 'not-inside' end
    for _, property in pairs(storage.properties) do
        if property.status == 'active'
                and property.surface_index == surface.index then
            local available, err, value = M.salvage_availability(
                player,
                property
            )
            return available, err, property, value
        end
    end
    return false, 'not-inside'
end

function M.salvage(player, property_id, quoted_value)
    local property = M.get(property_id)
    local available, err, value = M.salvage_availability(player, property)
    if not available then return false, err end
    quoted_value = tonumber(quoted_value)
    if quoted_value and value < quoted_value then
        return false, 'salvage-value-changed', value
    end
    local property_name = M.display_name(property)
    local ok, delete_err = delete_property_surface(property)
    if not ok then return false, delete_err end
    local paid, credit_err = economy.change(
        player.index,
        value,
        'property-salvage'
    )
    if not paid then
        log('[un] property salvage payout failed for property '
            .. property.id .. ': ' .. tostring(credit_err))
        return false, credit_err
    end
    game.print({
        'un.property-salvage-broadcast',
        player.name,
        property_name,
        value,
        factions.display_name(factions.of_player(player)),
    })
    return true, value
end

local function owned_player_property_availability(player, property)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    if property.owner_index ~= player.index then return false, 'not-owner' end
    if not (player.physical_surface
            and player.physical_surface.index == property.surface_index) then
        return false, 'not-inside'
    end
    if property.permanent then return false, 'permanent' end
    if not property.construction_type or not property.construction_level then
        return false, 'not-player-built'
    end
    return true
end

function M.renew_requirements(property)
    if not property or property.permanent then return nil end
    local level = tonumber(property.construction_level)
    local pack = build_type_by_key(property.construction_type)
    if not level or not pack then return nil end
    local base_cost = config.property_build_experience_base
        + config.property_build_experience_per_level * level
    local lifetime_ticks = tonumber(property.lifetime_hours)
        and property.lifetime_hours * config.ticks_per_hour or nil
    if not lifetime_ticks or lifetime_ticks <= 0 then return nil end
    local remaining_ticks = math.max(0, property.expires_tick - game.tick)
    local missing_ticks = math.max(0, lifetime_ticks - remaining_ticks)
    if missing_ticks <= 0 then return nil, 'lifetime-full' end
    local base_width = tonumber(property.base_width) or property.width
    local base_height = tonumber(property.base_height) or property.height
    local area_factor = property.width * property.height
        / (base_width * base_height)
    local experience_cost = math.max(1, math.ceil(
        base_cost * config.property_renew_experience_multiplier
            * missing_ticks / lifetime_ticks * area_factor
    ))
    return {
        pack = pack.pack,
        experience_cost = experience_cost,
        stamina_cost = config.property_renew_stamina_cost,
        lifetime_ticks = lifetime_ticks,
        missing_ticks = missing_ticks,
        area_factor = area_factor,
    }
end

function M.renew_availability(player, property)
    local available, err = owned_player_property_availability(player, property)
    if not available then return false, err end
    local requirement, requirement_err = M.renew_requirements(property)
    if not requirement then
        return false, requirement_err or 'not-player-built'
    end
    if experience.amount(player.index, requirement.pack)
            < requirement.experience_cost then
        return false, 'insufficient-experience', requirement
    end
    if stamina.get(player.index) < requirement.stamina_cost then
        return false, 'insufficient-stamina', requirement
    end
    return true, nil, requirement
end

function M.renew(player, property_id, quoted_experience_cost)
    local property = M.get(property_id)
    local available, err, requirement = M.renew_availability(player, property)
    if not available then return false, err, requirement end
    if quoted_experience_cost ~= nil
            and requirement.experience_cost ~= quoted_experience_cost then
        return false, 'management-cost-changed', requirement
    end
    if not experience.spend(
        player.index,
        requirement.pack,
        requirement.experience_cost
    ) then
        return false, 'insufficient-experience', requirement
    end
    if not stamina.spend(player.index, requirement.stamina_cost) then
        experience.record(player.index, {{
            name = requirement.pack,
            count = requirement.experience_cost,
        }})
        return false, 'insufficient-stamina', requirement
    end
    property.expires_tick = game.tick + requirement.lifetime_ticks
    property.renewal_count = (property.renewal_count or 0) + 1
    bump_revision()
    game.print({
        'un.property-renewed-broadcast',
        player.name,
        M.display_name(property),
        requirement.experience_cost,
        requirement.stamina_cost,
        factions.display_name(property.sample_planet),
    })
    return true, nil, requirement
end

function M.expansion_requirements(property)
    if not property or property.permanent then return nil end
    local build_type = build_type_by_key(property.construction_type)
    local stage = tonumber(property.expansion_stage) or 0
    local stages = tonumber(property.expansion_stages) or 0
    local level = tonumber(property.construction_level)
    if not build_type or not build_type.expandable or not level
            or stages <= 0 or stage >= stages then
        return nil
    end
    local next_stage = stage + 1
    local width = math.min(
        property.max_width,
        expansion_size(property.base_width or property.width, next_stage)
    )
    local height = math.min(
        property.max_height,
        expansion_size(property.base_height or property.height, next_stage)
    )
    if width <= property.width or height <= property.height then return nil end
    local lifetime_ticks = tonumber(property.lifetime_hours)
        and property.lifetime_hours * config.ticks_per_hour or nil
    if not lifetime_ticks or lifetime_ticks <= 0 then return nil end
    local experience_cost = math.ceil(
        (config.property_build_experience_base
            + config.property_build_experience_per_level * level)
        * config.property_expansion_experience_multiplier
        * ((width * height - property.width * property.height)
            / ((property.base_width or property.width)
                * (property.base_height or property.height)))
        * math.max(0, property.expires_tick - game.tick) / lifetime_ticks
    )
    experience_cost = math.max(1, experience_cost)
    return {
        pack = build_type.pack,
        experience_cost = experience_cost,
        stamina_cost = config.property_expansion_stamina_cost,
        stage = next_stage,
        width = width,
        height = height,
        layout = expansion_layout(build_type),
    }
end

function M.expansion_availability(player, property)
    local available, err = owned_player_property_availability(player, property)
    if not available then return false, err end
    local requirement = M.expansion_requirements(property)
    if not requirement then return false, 'not-expandable' end
    if experience.amount(player.index, requirement.pack)
            < requirement.experience_cost then
        return false, 'insufficient-experience', requirement
    end
    if stamina.get(player.index) < requirement.stamina_cost then
        return false, 'insufficient-stamina', requirement
    end
    return true, nil, requirement
end

function M.expand(player, property_id, quoted_experience_cost, quoted_stage)
    local property = M.get(property_id)
    local available, err, requirement = M.expansion_availability(player, property)
    if not available then return false, err, requirement end
    if (quoted_experience_cost ~= nil
            and requirement.experience_cost ~= quoted_experience_cost)
            or (quoted_stage ~= nil and requirement.stage ~= quoted_stage) then
        return false, 'management-cost-changed', requirement
    end
    if not experience.spend(
        player.index,
        requirement.pack,
        requirement.experience_cost
    ) then
        return false, 'insufficient-experience', requirement
    end
    if not stamina.spend(player.index, requirement.stamina_cost) then
        experience.record(player.index, {{
            name = requirement.pack,
            count = requirement.experience_cost,
        }})
        return false, 'insufficient-stamina', requirement
    end
    local expanded, expand_err = surfaces.expand_property_surface(
        property,
        requirement.width,
        requirement.height,
        requirement.layout
    )
    if not expanded then
        experience.record(player.index, {{
            name = requirement.pack,
            count = requirement.experience_cost,
        }})
        stamina.refund(player.index, requirement.stamina_cost)
        return false, expand_err, requirement
    end
    property.base_width = property.base_width or property.width
    property.base_height = property.base_height or property.height
    property.width = requirement.width
    property.height = requirement.height
    property.expansion_stage = requirement.stage
    ensure_property_name_rendering(
        property,
        property.rendered_name or property_rendering_fallback(property)
    )
    bump_revision()
    game.print({
        'un.property-expanded-broadcast',
        player.name,
        M.display_name(property),
        requirement.width,
        requirement.height,
        requirement.experience_cost,
        requirement.stamina_cost,
        factions.display_name(property.sample_planet),
    })
    return true, nil, requirement
end

local function expire_property(property)
    local expired_name = M.display_name(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then
        clear_name_translation_requests(property.id)
        storage.properties[property.id] = nil
        bump_revision()
        game.print({'un.property-expired', expired_name})
        return true
    end
    if delete_property_surface(property) then
        game.print({'un.property-expired', expired_name})
        return true
    end
    log('[un] failed to delete expired property ' .. property.id)
    return false
end

local function expire_due_properties()
    state.ensure()
    local due = {}
    for _, property in pairs(storage.properties) do
        if property.status == 'active' and property.expires_tick
                and property.expires_tick <= game.tick then
            due[#due + 1] = property
        end
    end
    table.sort(due, function(a, b) return a.id < b.id end)
    for _, property in ipairs(due) do expire_property(property) end
end

function M.admin_set_tax(player, percent)
    if not (player and player.valid and player.admin) then
        return false, 'not-admin'
    end
    percent = tonumber(percent)
    if not percent or percent < 0 or percent > 100 then
        return false, 'invalid-value'
    end
    local tax = percent / 100
    for _, property in ipairs(M.list()) do property.tax = tax end
    bump_revision()
    return true
end

events.on(defines.events.on_surface_deleted, function(event)
    state.ensure()
    local property_id = storage.deleting_properties[event.surface_index]
    if not property_id then return end
    storage.deleting_properties[event.surface_index] = nil
    clear_name_translation_requests(property_id)
    storage.properties[property_id] = nil
    bump_revision()
end)

events.on(defines.events.on_string_translated, function(event)
    state.ensure()
    local request = storage.property_name_translation_requests[event.id]
    if not request then return end
    storage.property_name_translation_requests[event.id] = nil
    local property = M.get(request.property_id)
    if not property then return end
    if request.created_tick
            and request.created_tick ~= property.created_tick then
        return
    end
    local owner_token = request.owner_token
    if owner_token == nil then owner_token = request.owner_index or 0 end
    if (property.owner_index or 0) ~= owner_token then return end
    if (property.owner_property_number or 0)
            ~= (request.owner_property_number or 0) then
        return
    end
    if type(property.custom_name) == 'string' then return end
    local player_index = request.player_index or request.owner_index
    if event.player_index ~= player_index or not event.translated then return end
    property.rendered_name = event.result
    local player = game.get_player(event.player_index)
    property.rendered_name_locale = player and player.locale or nil
    ensure_property_name_rendering(property, event.result)
end)

local function refresh_owned_name_renderings(event)
    local player = game.get_player(event.player_index)
    if not (player and player.connected) then return end
    for _, property in ipairs(M.list()) do
        if property.owner_index == player.index then
            request_property_name_translation(property, player)
        end
    end
end

events.on(defines.events.on_player_joined_game, refresh_owned_name_renderings)
events.on(defines.events.on_player_locale_changed, refresh_owned_name_renderings)

factions.on_switch_cleanup(function(player, source_planet)
    M.release_owner_in_faction(player.index, source_planet)
end)

scheduler.every(config.property_lifecycle_ticks, expire_due_properties)

return M
