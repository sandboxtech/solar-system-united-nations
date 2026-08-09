local config = require('config')
local economy = require('scripts.economy')
local events = require('scripts.events')
local experience = require('scripts.experience')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local social = require('scripts.social')
local state = require('scripts.state')
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

local function next_available_property_id()
    local id = 1
    while storage.properties[id]
            or game.surfaces[config.property_surface_prefix .. tostring(id)] do
        id = id + 1
    end
    return id
end

function M.display_name(property)
    if property.custom_name then return property.custom_name end
    if not property.owner_index then
        return {'un.property-surface-vacant', property.id}
    end
    local owner = game.get_player(property.owner_index)
    local account = storage.players[property.owner_index]
    local owner_name = owner and owner.name
        or account and account.name
        or ('#' .. property.owner_index)
    return {'un.property-surface-owned', owner_name, property.id}
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
        created_tick = property.created_tick,
    }
    return true
end

function M.feature_description(property)
    local width = property.width or property.size or 0
    local height = property.height or property.size or 0
    return {
        'un.property-features',
        width,
        height,
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
    property.solar = config.property_solar_multiplier
    property.min_brightness = config.property_min_brightness
    surfaces.sync_property_environment(
        surface,
        property.min_brightness,
        property.sample_planet
    )
    normalize_linked_chest_positions(property, surface)
    local link_id = property.owner_index or config.property_link_id_unowned
    for _, position in ipairs(property.linked_chest_positions) do
        local chest = surface.find_entity(config.linked_chest_name, position)
        if not (chest and chest.valid) then
            chest = surface.create_entity{
                name = config.linked_chest_name,
                position = position,
                force = game.forces.player,
                raise_built = false,
            }
        end
        if not (chest and chest.valid) then return false end
        chest.link_id = link_id
        chest.operable = false
        chest.destructible = false
        chest.minable = false
    end
    return true
end

local function sync_surface_visibility(property)
    local surface = game.surfaces[property.surface_name]
    local force = game.forces.player
    if not (surface and surface.valid and force and force.valid) then return false end
    force.set_surface_hidden(surface, property.owner_index ~= nil)
    return true
end

local function create(spec)
    state.ensure()
    spec = spec or {}
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
    local solar = config.property_solar_multiplier
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

    local id = next_available_property_id()
    local min_brightness = config.property_min_brightness
    local surface, half_width, half_height, sample_planet, sample_position
        = surfaces.create_property_surface(id, {
        width = width,
        height = height,
        sample_planet = spec.sample_planet,
    })
    if not surface then return nil, 'surface-create-failed' end
    storage.next_property_id = id + 1
    local property = {
        id = id,
        custom_name = nil,
        surface_name = surface.name,
        surface_index = surface.index,
        status = 'active',
        owner_index = spec.owner_index,
        base_price = price,
        price_at_tick = game.tick,
        decay_ticks = decay_hours * config.ticks_per_hour,
        tax = tax,
        width = width,
        height = height,
        solar = solar,
        min_brightness = min_brightness,
        sample_planet = sample_planet,
        sample_position = sample_position,
        linked_chest_positions = central_chest_positions(),
        created_tick = game.tick,
        expires_tick = permanent and nil
            or game.tick + lifetime_hours * config.ticks_per_hour,
        lifetime_hours = lifetime_hours,
        permanent = permanent,
        system_key = spec.system_key,
    }
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

function M.ensure()
    state.ensure()
    if not storage.permanent_properties_created then
        local complete = true
        for _, planet_name in ipairs(config.public_planets) do
            for tier_index, spec in ipairs(config.property_permanent_defaults) do
                for slot = 1, spec.count do
                    local key = table.concat({planet_name, tier_index, slot}, ':')
                    local existing = false
                    for _, property in pairs(storage.properties) do
                        if property.system_key == key then existing = true; break end
                    end
                    if not existing then
                        local property, err = create{
                            sample_planet = planet_name,
                            width = spec.width,
                            height = spec.height,
                            decay_hours = spec.decay_hours,
                            permanent = true,
                            system_key = key,
                        }
                        if not property then
                            complete = false
                            log('[un] failed to create permanent property '
                                .. key .. ': ' .. tostring(err))
                        end
                    end
                end
            end
        end
        if complete then storage.permanent_properties_created = true end
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

function M.build_requirements(planet_name, lifetime_index, size_index)
    local lifetime = config.property_lifetime_options[tonumber(lifetime_index)]
    local size = config.property_size_options[tonumber(size_index)]
    local pack = config.property_build_pack_by_planet[planet_name]
    if not (build_planets[planet_name] and lifetime and size and pack) then
        return nil
    end
    return {
        planet_name = planet_name,
        pack = pack,
        lifetime = lifetime,
        size = size,
        experience_cost = config.property_build_experience_per_point
            * lifetime.cost * size.cost,
    }
end

function M.build_availability(player, planet_name, lifetime_index, size_index)
    local requirement = M.build_requirements(
        planet_name,
        lifetime_index,
        size_index
    )
    if not requirement then return false, 'invalid-build-option' end
    if not surfaces.is_public_planet_open(planet_name) then
        return false, 'planet-closed', requirement
    end
    if experience.amount(player.index, requirement.pack)
            < requirement.experience_cost then
        return false, 'insufficient-experience', requirement
    end
    return true, nil, requirement
end

function M.build(player, planet_name, lifetime_index, size_index)
    local available, err, requirement = M.build_availability(
        player,
        planet_name,
        lifetime_index,
        size_index
    )
    if not available then return nil, err, requirement end
    if not experience.spend(
        player.index,
        requirement.pack,
        requirement.experience_cost
    ) then
        return nil, 'insufficient-experience', requirement
    end
    local ok, property, create_err = pcall(create, {
        owner_index = player.index,
        sample_planet = planet_name,
        lifetime_hours = requirement.lifetime.hours,
        decay_hours = requirement.lifetime.decay_hours,
        width = requirement.size.width,
        height = requirement.size.height,
    })
    if not ok or not property then
        experience.record(player.index, {{
            name = requirement.pack,
            count = requirement.experience_cost,
        }})
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
        {'', '[planet=' .. planet_name .. '] ',
            {'space-location-name.' .. planet_name}},
        requirement.experience_cost,
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

function M.transaction_tax_rate(property)
    local level = property.owner_index
        and experience.total_level(property.owner_index) or 0
    return property.tax / (level / 100 + 1)
end

function M.transaction_tax(property, price)
    if not property.owner_index then return price end
    local payout = math.floor(price * (1 - M.transaction_tax_rate(property)))
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

function M.owned_count(player_index)
    local count = 0
    for _, property in ipairs(M.list()) do
        if property.owner_index == player_index then count = count + 1 end
    end
    return count
end

function M.release_owner(player_index)
    state.ensure()
    local changed = 0
    for _, property in ipairs(M.list()) do
        if property.owner_index == player_index then
            property.owner_index = nil
            property.owner_cleanup_tick = game.tick
            ensure_linked_chests(property)
            sync_surface_visibility(property)
            local translator = first_connected_player()
            if translator then
                request_property_name_translation(property, translator)
            end
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
    local price = M.current_price(property)
    local required = property.owner_index == player.index
        and M.transaction_tax(property, price) or price
    if economy.get_balance(player.index) < required then
        return false, 'insufficient-credit'
    end
    return true
end

function M.enter_availability(player, property)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    if player.admin and settings.get('admin_property_access') then return true end
    if player.vehicle and player.vehicle.valid then return false, 'in-vehicle' end
    if not surfaces.can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    if property.owner_index == player.index then return true end
    if M.all_open(property.owner_index) then return true end
    if social.are_mutual(player.index, property.owner_index) then return true end
    return false, 'not-owner'
end

function M.buy(player, property_id, quoted_price)
    local property = M.get(property_id)
    if not property then return false, 'missing' end
    if not valid_surface(property) then return false, 'surface-missing' end
    local price = M.current_price(property)
    local seller_name = M.owner_name(property)
    local transaction_name = property.custom_name
        or {'un.property-default-name', property.id}
    if quoted_price and price > quoted_price then return false, 'price-increased', price end
    local payout = property.owner_index
        and math.floor(price * (1 - M.transaction_tax_rate(property))) or 0
    local tax = price - payout
    local ok, err = economy.taxed_transfer(
        player.index,
        property.owner_index,
        price,
        payout,
        'property-purchase'
    )
    if not ok then return false, err end

    property.owner_index = player.index
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
    if seller_name then
        game.print({
            'un.property-purchase-player-broadcast',
            player.name,
            price,
            seller_name,
            transaction_name,
            payout,
            tax,
        })
    else
        game.print({
            'un.property-purchase-vacant-broadcast',
            player.name,
            price,
            transaction_name,
            price,
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
    ensure_linked_chests(property)
    local ok, err
    if player.admin and settings.get('admin_property_access') then
        ok, err = surfaces.teleport_near(player, surface, {0, 0}, false)
    else
        ok, err = surfaces.teleport(player, surface)
    end
    if ok and property.owner_index == player.index then
        local account = economy.ensure_account(player.index)
        account.last_property_id = property.id
        account.last_property_by_planet = account.last_property_by_planet or {}
        account.last_property_by_planet[property.sample_planet] = property.id
    end
    return ok, err
end

function M.enter_last_owned(player)
    return M.home_travel(player)
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

function M.home_travel(player)
    local source = player.physical_surface
    local planet_name = surfaces.context_planet(source)
    if not planet_name then return false, 'travel-restricted' end
    if source.name == planet_name then
        local property = owned_home(player.index, planet_name)
        if property then return M.enter(player, property.id) end
        return surfaces.to_hospice(player, planet_name)
    end
    return surfaces.to_planet_origin(player, planet_name)
end

local function command_player(command)
    return command.player_index and game.get_player(command.player_index) or nil
end

local function reply(command, message)
    local player = command_player(command)
    if player then player.print(message) else localised_print(message) end
end

local function property_at_player_body(player)
    local surface = player.physical_surface
    if not (surface and surface.valid) then return nil end
    for _, property in ipairs(M.list()) do
        if property.surface_index == surface.index then return property end
    end
    return nil
end

local function valid_custom_name(name)
    if name == '' or #name > 256 or name:find('%c') then return false end
    local characters = 0
    for index = 1, #name do
        local byte = name:byte(index)
        if byte < 128 or byte >= 192 then characters = characters + 1 end
    end
    return characters <= 64
end

local function rename_from_command(command, parameter)
    local player = command_player(command)
    if not player then
        reply(command, {'un.property-rename-player-only'})
        return
    end
    local property = property_at_player_body(player)
    if not property then
        player.print({'un.property-rename-not-inside'})
        return
    end
    if property.owner_index ~= player.index then
        player.print({'un.property-rename-not-owner'})
        return
    end
    local name = parameter:match('^%s*rename%s+(.+)%s*$') or ''
    name = name:match('^%s*(.-)%s*$') or ''
    if not valid_custom_name(name) then
        player.print({'un.property-rename-invalid'})
        return
    end
    property.custom_name = name
    property.rendered_name = name
    property.rendered_name_locale = nil
    ensure_linked_chests(property)
    ensure_property_name_rendering(property, name)
    bump_revision()
    player.print({'un.property-renamed', property.id, name})
end

local function evacuate_expired_property(property, surface)
    local hospice = surfaces.ensure_hospice(property.sample_planet)
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
    evacuate_expired_property(property, surface)
    property.status = 'deleting'
    storage.deleting_properties[surface.index] = property.id
    if game.delete_surface(surface) then
        bump_revision()
        game.print({'un.property-expired', expired_name})
        return true
    end
    storage.deleting_properties[surface.index] = nil
    property.status = 'active'
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

function M.admin_repair(player)
    if not (player and player.valid and player.admin) then
        return false, 'not-admin'
    end
    M.ensure()
    for _, property in ipairs(M.list()) do ensure_linked_chests(property) end
    bump_revision()
    return true, #M.list()
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

local function on_command(command)
    state.ensure()
    local parameter = command.parameter or ''
    local action = parameter:match('^%s*(%S*)')
    if action == 'rename' then
        rename_from_command(command, parameter)
        return
    end
    reply(command, {'un.property-command-usage'})
end

commands.add_command('un-property', {'un.property-command-help'}, on_command)

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
        elseif not property.owner_index then
            request_property_name_translation(property, player)
        end
    end
end

events.on(defines.events.on_player_joined_game, refresh_owned_name_renderings)
events.on(defines.events.on_player_locale_changed, refresh_owned_name_renderings)

scheduler.every(config.property_lifecycle_ticks, expire_due_properties)

return M
