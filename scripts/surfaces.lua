local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')

local M = {}
local TUTORIAL_GRID_NAME = 'tutorial-grid'
local public_planets = {}
for _, name in ipairs(config.public_planets) do
    public_planets[name] = true
end
local function property_build_type(key)
    for _, spec in ipairs(config.property_build_types or {}) do
        if spec.key == key then return spec end
    end
    return nil
end
local function map_gen_settings(width, height)
    return {
        width = width,
        height = height or width,
        water = 0,
        peaceful_mode = true,
        no_enemies_mode = true,
        default_enable_all_autoplace_controls = false,
        autoplace_settings = {
            entity = {treat_missing_as_default = false, settings = {}},
            decorative = {treat_missing_as_default = false, settings = {}},
        },
    }
end

local function ensure_generated(surface, radius)
    surface.request_to_generate_chunks({0, 0}, radius or 1)
    surface.force_generate_chunk_requests()
end

local function fill_tile_area(surface, left, top, right, bottom, tile_name)
    local tiles = {}
    for y = top, bottom - 1 do
        for x = left, right - 1 do
            tiles[#tiles + 1] = {name = tile_name, position = {x, y}}
            if #tiles >= 65536 then
                surface.set_tiles(tiles, false, false, false, false)
                tiles = {}
            end
        end
    end
    if #tiles > 0 then
        surface.set_tiles(tiles, false, false, false, false)
    end
end

local function property_bounds(width, height, base_height, anchored_up)
    local left = -math.floor(width / 2)
    local right = left + width
    local centered_top = -math.floor(height / 2)
    local top = centered_top
    local bottom = top + height
    if anchored_up then
        bottom = 0
        top = bottom - height
    end
    return {
        left = left,
        top = top,
        right = right,
        bottom = bottom,
        offset_y = top - centered_top,
    }
end

local function property_special_bounds(bounds)
    return {
        left = bounds.left,
        top = bounds.top,
        right = bounds.right,
        bottom = math.max(bounds.bottom, 4),
    }
end

local function apply_property_special_tiles(surface, half_width, half_height, spec,
        exclude_bounds, active_bounds)
    if type(spec.special_areas) ~= 'table' then return end
    for _, area in ipairs(spec.special_areas) do
        local tiles = {}
        local bounds = active_bounds or {
            left = -half_width,
            top = -half_height,
            right = half_width,
            bottom = half_height,
        }
        local left = tonumber(area.left)
        local right = tonumber(area.right)
        if area.direction == 'full' then
            left = bounds.left
            right = bounds.right
        elseif area.direction == 'right' then
            left = tonumber(area.start) or 0
            right = bounds.right
        elseif area.direction == 'left' then
            left = bounds.left
            right = tonumber(area.finish) or 0
        end
        left = math.max(bounds.left, left or 0)
        right = math.min(bounds.right, right or 0)
        local top = math.max(bounds.top, tonumber(area.top) or 0)
        local bottom = math.min(
            bounds.bottom,
            tonumber(area.bottom) or top + (tonumber(area.thickness) or 0)
        )
        if type(area.tile) == 'string' then
            for y = top, bottom - 1 do
                for x = left, right - 1 do
                    local excluded = exclude_bounds
                        and x >= exclude_bounds.left
                        and x < exclude_bounds.right
                        and y >= exclude_bounds.top
                        and y < exclude_bounds.bottom
                    if not excluded then
                        tiles[#tiles + 1] = {
                            name = area.tile,
                            position = {x, y},
                        }
                    end
                end
            end
        end
        -- Apply each layer separately so later entrance-platform rectangles
        -- deterministically replace the functional strip beneath them.
        if #tiles > 0 then
            surface.set_tiles(tiles, false, false, true, false)
        end
    end
end

local function clear_property_lower_half(surface, spec, active_bounds,
        exclude_bounds)
    if not spec.lower_half_out_of_map then return end
    local tiles = {}
    local top = math.max(0, active_bounds.top)
    for y = top, active_bounds.bottom - 1 do
        for x = active_bounds.left, active_bounds.right - 1 do
            local excluded = exclude_bounds
                and x >= exclude_bounds.left
                and x < exclude_bounds.right
                and y >= exclude_bounds.top
                and y < exclude_bounds.bottom
            if not excluded then
                tiles[#tiles + 1] = {
                    name = 'out-of-map',
                    position = {x, y},
                }
            end
        end
    end
    if #tiles > 0 then
        surface.set_tiles(tiles, false, false, true, false)
    end
end

local function apply_property_entrance_tiles(surface, offset_y)
    offset_y = offset_y or 0
    local tiles = {}
    for y = 1, 3 do
        for x = -2, 1 do
            tiles[#tiles + 1] = {
                name = 'tutorial-grid',
                position = {x, y + offset_y},
            }
        end
    end
    surface.set_tiles(tiles, false, false, true, false)
end

local function apply_fixed_property_tiles(surface, half_width, half_height, layout,
        exclude_bounds, destination_offset_y)
    destination_offset_y = destination_offset_y or 0
    local middle_half = (tonumber(layout.middle_size) or 0) / 2
    local core_half = (tonumber(layout.core_size) or 0) / 2
    local chunk_size = tonumber(layout.chunk_size) or 0
    local chunk_inner_size = tonumber(layout.chunk_inner_size) or 0
    local chunk_margin = (chunk_size - chunk_inner_size) / 2
    local railway_corridor_length
        = tonumber(layout.railway_corridor_length) or 0
    local railway_corridor_half
        = (tonumber(layout.railway_corridor_height) or 0) / 2
    local width = math.floor(half_width * 2 + 0.5)
    local height = math.floor(half_height * 2 + 0.5)
    local left = -math.floor(width / 2)
    local top = -math.floor(height / 2)
    local right = left + width
    local bottom = top + height
    local tiles = {}
    for y = top, bottom - 1 do
        for x = left, right - 1 do
            local destination_y = y + destination_offset_y
            local excluded = exclude_bounds
                and x >= exclude_bounds.left and x < exclude_bounds.right
                and destination_y >= exclude_bounds.top
                and destination_y < exclude_bounds.bottom
            if not excluded then
            local in_core = core_half > 0
                and x >= -core_half and x < core_half
                and y >= -core_half and y < core_half
            local in_middle = middle_half > 0
                and x >= -middle_half and x < middle_half
                and y >= -middle_half and y < middle_half
            local tile_name = in_core and layout.core_tile or nil
            if not tile_name and layout.rectangles then
                for _, rectangle in ipairs(layout.rectangles) do
                    if x >= rectangle.left and x < rectangle.right
                            and y >= rectangle.top and y < rectangle.bottom then
                        tile_name = rectangle.tile
                        break
                    end
                end
            end
            if not tile_name and railway_corridor_length > 0 then
                local corridor_left = -math.floor(railway_corridor_length / 2)
                local corridor_right = corridor_left + railway_corridor_length
                local in_room = x < corridor_left or x >= corridor_right
                local in_corridor = y >= -railway_corridor_half
                    and y < railway_corridor_half
                if in_room or in_corridor then
                    tile_name = layout.railway_tile
                end
            end
            if not tile_name and chunk_size > 0 and chunk_inner_size > 0 then
                local local_x = x % chunk_size
                local local_y = y % chunk_size
                if local_x >= chunk_margin
                        and local_x < chunk_size - chunk_margin
                        and local_y >= chunk_margin
                        and local_y < chunk_size - chunk_margin then
                    tile_name = layout.chunk_grid_tile
                end
            end
            tiles[#tiles + 1] = {
                name = tile_name or in_middle and layout.middle_tile
                    or layout.fill_tile,
                position = {x, destination_y},
            }
            end
        end
    end
    if #tiles > 0 then surface.set_tiles(tiles, true, false, true, false) end
end

local function apply_hospice_tiles(surface, planet_name)
    local key = config.hospice_property_types_by_planet[planet_name]
    local spec = property_build_type(key)
    if not spec then return false end
    local level = config.hospice_property_level
    local width = math.min(
        spec.max_width,
        math.floor((spec.base_width + spec.width_per_level * level) / 2) * 2
    )
    local height = math.min(
        spec.max_height,
        math.floor((spec.height + spec.height_per_level * level) / 2) * 2
    )
    local surface_width = math.max(config.hospice_surface_width, width)
    local surface_height = math.max(config.hospice_surface_height, height)
    local map_settings = surface.map_gen_settings
    map_settings.width = surface_width
    map_settings.height = surface_height
    surface.map_gen_settings = map_settings
    local half_width = width / 2
    local half_height = height / 2
    local bounds = property_bounds(width, height, spec.height, true)
    fill_tile_area(
        surface,
        -surface_width / 2,
        -surface_height / 2,
        surface_width / 2,
        surface_height / 2,
        'out-of-map'
    )
    local sample_planet = spec.terrain_planet or planet_name
    apply_fixed_property_tiles(
        surface,
        half_width,
        half_height,
        spec.fixed_layout or {fill_tile = TUTORIAL_GRID_NAME},
        nil,
        bounds.offset_y
    )
    if not sample_planet then return false end
    local special_bounds = property_special_bounds(bounds)
    clear_property_lower_half(surface, spec, special_bounds, nil)
    apply_property_special_tiles(
        surface,
        half_width,
        half_height,
        spec,
        nil,
        special_bounds
    )
    apply_property_entrance_tiles(surface, -3)
    return true
end

function M.hospice_surface_name(planet_name)
    return config.hospice_surface_prefix .. (planet_name or 'nauvis')
end

function M.hospice_planet(surface)
    if not (surface and surface.valid) then return nil end
    local prefix = config.hospice_surface_prefix
    if surface.name:sub(1, #prefix) ~= prefix then return nil end
    local name = surface.name:sub(#prefix + 1)
    return public_planets[name] and name or nil
end

function M.property_planet(surface)
    if not (surface and surface.valid) then return nil end
    for _, property in pairs(storage.properties or {}) do
        if property.surface_index == surface.index then return property.sample_planet end
    end
    return nil
end

function M.context_planet(surface)
    if not (surface and surface.valid) then return nil end
    if public_planets[surface.name] then return surface.name end
    return M.hospice_planet(surface) or M.property_planet(surface)
end

function M.ensure_hospice(planet_name)
    planet_name = public_planets[planet_name] and planet_name or 'nauvis'
    local surface_name = M.hospice_surface_name(planet_name)
    local surface = game.surfaces[surface_name]
    if not (surface and surface.valid) then
        surface = game.create_surface(
            surface_name,
            map_gen_settings(
                config.hospice_surface_width,
                config.hospice_surface_height
            )
        )
    else
        local settings = surface.map_gen_settings
        settings.width = config.hospice_surface_width
        settings.height = config.hospice_surface_height
        surface.map_gen_settings = settings
    end
    ensure_generated(
        surface,
        math.max(1, math.ceil(math.max(
            config.hospice_surface_width,
            config.hospice_surface_height
        ) / 64))
    )
    if storage.hospice_grid_versions[planet_name]
            ~= config.hospice_tile_layout_version then
        apply_hospice_tiles(surface, planet_name)
        storage.hospice_grid_versions[planet_name] =
            config.hospice_tile_layout_version
    end
    surface.localised_name = {
        'un.hospice-name-planet',
        {'space-location-name.' .. planet_name},
    }
    M.sync_property_environment(surface, nil, planet_name, true)
    local force = factions.of_planet(planet_name)
    if force and force.valid then force.set_spawn_position({0, 0}, surface) end
    return surface
end

-- Travel and respawn only need an existing destination.  Re-running
-- ensure_hospice for every click used to rewrite map-gen settings, force
-- chunk generation, and resynchronise every surface property on the main
-- simulation thread.  Creation and repair remain owned by bootstrap.
function M.hospice_surface(planet_name)
    planet_name = public_planets[planet_name] and planet_name or 'nauvis'
    local surface = game.surfaces[M.hospice_surface_name(planet_name)]
    if surface and surface.valid then return surface end
    return M.ensure_hospice(planet_name)
end

function M.sync_property_environment(
        surface, min_brightness, planet_name, use_planet_solar,
        construction_type)
    if not (surface and surface.valid) then return false end
    local planet = game.planets[planet_name or 'nauvis']
    if not (planet and planet.valid) then return false end
    local defaults = planet.prototype.surface_properties or {}
    local property_names = {}
    for name in pairs(prototypes.surface_property) do
        property_names[#property_names + 1] = name
    end
    table.sort(property_names)
    for _, name in ipairs(property_names) do
        local value = defaults[name]
        if value == nil then
            value = prototypes.surface_property[name].default_value
        end
        local overrides = nil
        if construction_type then
            for _, build_type in ipairs(config.property_build_types) do
                if build_type.key == construction_type then
                    overrides = build_type.surface_property_overrides
                    break
                end
            end
        end
        if overrides and overrides[name] ~= nil then
            value = overrides[name]
        end
        pcall(function() surface.set_property(name, value) end)
    end
    local cycle = surface.get_property('day-night-cycle')
    if cycle == 0 then
        surface.always_day = true
        surface.freeze_daytime = true
        surface.ticks_per_day = 1
    else
        surface.daytime_parameters = config.property_daytime_parameters
        surface.ticks_per_day = math.max(1, math.floor(cycle + 0.5))
        surface.always_day = false
        surface.freeze_daytime = false
    end
    -- `solar-power` is already a percentage multiplier. The independent
    -- LuaSurface multiplier is compounded with it, so copying the planet's
    -- percentage into both places would square the result (Vulcanus 400%
    -- became 1600%). Refugee camps use the planetary value unchanged;
    -- properties apply only their additional configured factor.
    surface.solar_power_multiplier = use_planet_solar
        and 1
        or config.property_solar_multiplier
    surface.min_brightness = min_brightness or config.property_min_brightness
    local planet_surface = game.surfaces[planet_name or 'nauvis']
    if planet_surface and planet_surface.valid then
        surface.daytime = planet_surface.daytime
    end
    return true
end

function M.sync_hospice_environment(planet_name)
    planet_name = public_planets[planet_name] and planet_name or 'nauvis'
    local surface = game.surfaces[M.hospice_surface_name(planet_name)]
    if not (surface and surface.valid) then return false end
    return M.sync_property_environment(surface, nil, planet_name, true)
end

function M.sync_all_hospice_environments()
    for _, planet_name in ipairs(config.public_planets) do
        M.sync_hospice_environment(planet_name)
    end
end

function M.sync_all_property_environments()
    for _, property in pairs(storage.properties or {}) do
        local surface = game.surfaces[property.surface_name]
        if surface and surface.valid then
            M.sync_property_environment(
                surface,
                nil,
                property.terrain_planet or property.sample_planet,
                nil,
                property.construction_type
            )
        end
    end
end

function M.create_property_surface(property_id, spec)
    local width = spec.width
    local height = spec.height
    local half_width = width / 2
    local half_height = height / 2
    local surface_width = spec.surface_width or width
    local surface_height = spec.surface_height or height
    local surface_half_width = surface_width / 2
    local surface_half_height = surface_height / 2
    local active_bounds = property_bounds(
        width,
        height,
        spec.layout_base_height or height,
        spec.layout_anchor_up == true
    )
    local requested_planet = public_planets[spec.terrain_planet]
        and spec.terrain_planet or spec.sample_planet
    local reset = storage.public_planet_resets
        and storage.public_planet_resets[requested_planet]
    if reset and reset.state ~= 'open' then
        return nil, nil, nil, nil, nil
    end
    local name = config.property_surface_prefix .. tostring(property_id)
    local surface = game.surfaces[name]
    if not (surface and surface.valid) then
        surface = game.create_surface(
            name,
            map_gen_settings(surface_width, surface_height)
        )
    end
    ensure_generated(surface, math.max(
        1,
        math.ceil(math.max(width, height) / 64)
    ))
    fill_tile_area(
        surface,
        -surface_half_width,
        -surface_half_height,
        surface_half_width,
        surface_half_height,
        'out-of-map'
    )
    local sample_planet = requested_planet
    local sample_position = nil
    apply_fixed_property_tiles(
        surface,
        half_width,
        half_height,
        spec.fixed_layout or {fill_tile = TUTORIAL_GRID_NAME},
        nil,
        active_bounds.offset_y
    )
    if not sample_planet then return nil, nil, nil, nil, nil end
    local special_bounds = property_special_bounds(active_bounds)
    clear_property_lower_half(surface, spec, special_bounds, nil)
    apply_property_special_tiles(
        surface,
        half_width,
        half_height,
        spec,
        nil,
        special_bounds
    )
    apply_property_entrance_tiles(surface)
    M.sync_property_environment(
        surface,
        nil,
        sample_planet,
        nil,
        spec.construction_type
    )
    surface.localised_name = spec.name or {'un.property-default-name', property_id}
    local force = factions.of_planet(spec.sample_planet)
    if force and force.valid then
        force.set_spawn_position({0, 0}, surface)
        force.chart(surface, {
            {active_bounds.left, active_bounds.top},
            {active_bounds.right, active_bounds.bottom},
        })
    end
    return surface, half_width, half_height, sample_planet, sample_position
end

function M.expand_property_surface(property, new_width, new_height, layout)
    local surface = property and game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    local old_width = tonumber(property.width)
    local old_height = tonumber(property.height)
    local max_width = tonumber(property.max_width)
    local max_height = tonumber(property.max_height)
    if not old_width or not old_height or not max_width or not max_height
            or new_width < old_width or new_height < old_height
            or (new_width == old_width and new_height == old_height)
            or new_width > max_width or new_height > max_height then
        return false, 'invalid-expansion'
    end
    local anchored_up = property.layout_anchor_up == true
    local layout_base_height = tonumber(property.layout_base_height) or old_height
    local old_bounds = property_bounds(
        old_width, old_height, layout_base_height, anchored_up
    )
    local new_bounds = property_bounds(
        new_width, new_height, layout_base_height, anchored_up
    )
    local half_width = new_width / 2
    local half_height = new_height / 2
    ensure_generated(surface, math.max(
        1,
        math.ceil(math.max(new_width, new_height) / 64)
    ))
    apply_fixed_property_tiles(
        surface,
        half_width,
        half_height,
        layout.fixed_layout or {fill_tile = TUTORIAL_GRID_NAME},
        old_bounds,
        new_bounds.offset_y
    )
    local special_bounds = property_special_bounds(new_bounds)
    clear_property_lower_half(surface, layout, special_bounds, old_bounds)
    apply_property_special_tiles(
        surface,
        half_width,
        half_height,
        layout,
        old_bounds,
        special_bounds
    )
    local force = factions.of_planet(property.sample_planet)
    if force and force.valid then
        force.chart(surface, {
            {new_bounds.left, new_bounds.top},
            {new_bounds.right, new_bounds.bottom},
        })
    end
    return true
end

local function safe_position(surface, center)
    local center_x = center.x or center[1]
    local center_y = center.y or center[2]
    local chunk = {
        x = math.floor(center_x / 32),
        y = math.floor(center_y / 32),
    }
    if not surface.is_chunk_generated(chunk) then
        surface.request_to_generate_chunks(center, 3)
        surface.force_generate_chunk_requests()
    end
    return surface.find_non_colliding_position('character', center, 64, 1)
end

function M.can_start_public_travel(surface)
    if not (surface and surface.valid) then return false end
    if public_planets[surface.name] then return true end
    if M.hospice_planet(surface) then return true end
    return surface.name:sub(1, #config.property_surface_prefix)
        == config.property_surface_prefix
end

function M.is_public_planet_open(name)
    local records = storage.public_planet_resets
    local record = records and records[name]
    return not record or record.state == 'open'
end

function M.teleport_physical(player, position, surface)
    if not (player and player.valid and surface and surface.valid) then
        return false, 'surface-missing'
    end
    if player.connected
            and player.controller_type == defines.controllers.remote then
        local exited = pcall(function() player.exit_remote_view() end)
        if not exited or player.controller_type == defines.controllers.remote then
            return false, 'travel-restricted'
        end
    end
    return player.teleport(position, surface)
end

function M.teleport_near(player, surface, center, allow_vehicle)
    if not (surface and surface.valid) then return false, 'surface-missing' end
    if not allow_vehicle
            and player.physical_vehicle
            and player.physical_vehicle.valid then
        return false, 'in-vehicle'
    end
    local position = safe_position(surface, center)
    if not position then position = {0, 2} end
    return M.teleport_physical(player, position, surface)
end

function M.teleport(player, surface)
    if not M.can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    return M.teleport_near(player, surface, {0, 0}, false)
end

local function recorded_hospice_center(surface, record)
    if type(record) ~= 'table' or record.surface_index ~= surface.index then
        return nil
    end
    local position = record.position
    if type(position) ~= 'table'
            or type(position.x) ~= 'number'
            or type(position.y) ~= 'number'
            or position.x ~= position.x
            or position.y ~= position.y
            or math.abs(position.x) > config.hospice_surface_width / 2
            or math.abs(position.y) > config.hospice_surface_height / 2 then
        return nil
    end
    return position
end

function M.to_hospice(player, planet_name, return_record)
    planet_name = planet_name or M.context_planet(player.physical_surface) or 'nauvis'
    local surface = M.hospice_surface(planet_name)
    if not M.can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    local center = recorded_hospice_center(surface, return_record) or {0, 0}
    return M.teleport_near(player, surface, center, false)
end

local function recorded_center(surface, planet_name, record)
    if type(record) ~= 'table' or record.surface_index ~= surface.index then
        return nil
    end
    local reset = storage.public_planet_resets
        and storage.public_planet_resets[planet_name]
    if record.round ~= (reset and reset.round or 0) then return nil end
    local position = record.position
    if type(position) ~= 'table'
            or type(position.x) ~= 'number'
            or type(position.y) ~= 'number' then
        return nil
    end
    return position
end

local function weighted_arrival_axis(radius)
    return math.floor((math.random() - math.random()) * radius)
end

function M.to_planet_origin(player, planet_name, return_record)
    local source = player.physical_surface
    if not M.can_start_public_travel(source) then
        return false, 'travel-restricted'
    end
    planet_name = public_planets[planet_name] and planet_name or 'nauvis'
    if not M.is_public_planet_open(planet_name) then
        return false, 'planet-closed'
    end
    local surface = game.surfaces[planet_name]
    if not (surface and surface.valid) then return false, 'surface-missing' end
    if player.physical_vehicle and player.physical_vehicle.valid then
        return false, 'in-vehicle'
    end
    local preferred_center = recorded_center(surface, planet_name, return_record)
    if preferred_center then
        local position = safe_position(surface, preferred_center)
        if position then return M.teleport_physical(player, position, surface) end
    end
    local radius = config.public_planet_arrival_radius
    for _ = 1, 32 do
        local center = {
            x = weighted_arrival_axis(radius),
            y = weighted_arrival_axis(radius),
        }
        local chunk = {
            x = math.floor(center.x / 32),
            y = math.floor(center.y / 32),
        }
        if surface.is_chunk_generated(chunk) then
            local position = surface.find_non_colliding_position(
                'character',
                center,
                8,
                1
            )
            if position and math.abs(position.x) < radius
                    and math.abs(position.y) < radius then
                return M.teleport_physical(player, position, surface)
            end
        end
    end
    local fallback_center = {
        x = weighted_arrival_axis(radius),
        y = weighted_arrival_axis(radius),
    }
    local fallback_position = safe_position(surface, fallback_center)
    if fallback_position and math.abs(fallback_position.x) < radius
            and math.abs(fallback_position.y) < radius then
        return M.teleport_physical(player, fallback_position, surface)
    end
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.suicide(player, planet_name)
    return factions.switch_by_suicide(player, planet_name)
end

local function respawn_destination(player)
    local planet_name = storage.respawn_hospice_planets[player.index]
    if planet_name then
        storage.respawn_hospice_planets[player.index] = nil
    else
        planet_name = factions.of_player(player) or 'nauvis'
    end
    return M.hospice_surface(planet_name), {0, 0}
end

events.on(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then M.to_hospice(player, 'nauvis') end
end)

events.on(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local surface, center = respawn_destination(player)
    local ok, err = M.teleport_near(player, surface, center, true)
    if not ok then
        log('[un] failed to move respawned player ' .. player.index .. ': ' .. tostring(err))
    end
end)

return M
