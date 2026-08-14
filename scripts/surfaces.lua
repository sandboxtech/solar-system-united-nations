local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')

local M = {}
local TUTORIAL_GRID_NAME = 'tutorial-grid'
local public_planets = {}
for _, name in ipairs(config.public_planets) do
    public_planets[name] = true
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

local function ensure_planet_surface(planet_name)
    local surface = game.surfaces[planet_name]
    if surface and surface.valid then return surface end
    local planet = game.planets[planet_name]
    if not (planet and planet.valid) then return nil end
    return planet.create_surface()
end

local function clone_planet_tile_area(
        destination, planet_name, source_area, destination_area, radius,
        source_center, clone_natural_entities)
    local source = ensure_planet_surface(planet_name)
    if not (source and source.valid) then return false end
    source.request_to_generate_chunks(source_center or {0, 0}, radius or 1)
    source.force_generate_chunk_requests()
    source.clone_area{
        source_area = source_area,
        destination_area = destination_area,
        destination_surface = destination,
        clone_tiles = true,
        clone_entities = false,
        clone_decoratives = false,
        clear_destination_entities = false,
        clear_destination_decoratives = true,
        expand_map = false,
    }
    if clone_natural_entities then
        local source_left = source_area[1][1]
        local source_top = source_area[1][2]
        local source_right = source_area[2][1]
        local source_bottom = source_area[2][2]
        local destination_left = destination_area[1][1]
        local destination_top = destination_area[1][2]
        local entities = source.find_entities_filtered{
            area = source_area,
            type = {'resource', 'simple-entity'},
        }
        table.sort(entities, function(a, b)
            if a.position.y ~= b.position.y then
                return a.position.y < b.position.y
            end
            if a.position.x ~= b.position.x then
                return a.position.x < b.position.x
            end
            if a.name ~= b.name then return a.name < b.name end
            return (a.unit_number or 0) < (b.unit_number or 0)
        end)
        local failed = 0
        for _, entity in ipairs(entities) do
            local position = entity.position
            -- The area filter also returns large entities whose collision box
            -- merely crosses the edge. Clone only centres inside the sample.
            if position.x >= source_left and position.x < source_right
                    and position.y >= source_top
                    and position.y < source_bottom then
                local cloned = entity.clone{
                    position = {
                        x = destination_left + position.x - source_left,
                        y = destination_top + position.y - source_top,
                    },
                    surface = destination,
                    create_build_effect_smoke = false,
                }
                if not cloned then failed = failed + 1 end
            end
        end
        if failed > 0 then
            log('[un] failed to clone ' .. failed
                .. ' natural entities into ' .. destination.name)
        end
    end
    return true
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
        bottom = config.property_layout_bottom_y
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
        layout_offset_y = bounds.bottom,
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
        local layout_offset_y = tonumber(bounds.layout_offset_y) or 0
        local requested_top = (tonumber(area.top) or 0) + layout_offset_y
        local requested_bottom = tonumber(area.bottom)
        if requested_bottom then
            requested_bottom = requested_bottom + layout_offset_y
        end
        local top = math.max(bounds.top, requested_top)
        local bottom = math.min(
            bounds.bottom,
            requested_bottom or top + (tonumber(area.thickness) or 0)
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
            surface.set_tiles(tiles, true, false, true, false)
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

function M.apply_entrance_tiles(surface, top_y)
    if not (surface and surface.valid) then return false end
    top_y = top_y or 1
    local tiles = {}
    for y = top_y, top_y + 2 do
        for x = -2, 1 do
            tiles[#tiles + 1] = {
                name = 'tutorial-grid',
                position = {x, y},
            }
        end
    end
    surface.set_tiles(tiles, true, false, true, false)
    return true
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
    local destination_bottom = bottom + destination_offset_y
    local tiles = {}
    for y = top, bottom - 1 do
        for x = left, right - 1 do
            local destination_y = y + destination_offset_y
            local feature_y = layout.feature_anchor_up
                and destination_y - destination_bottom or y
            local excluded = exclude_bounds
                and x >= exclude_bounds.left and x < exclude_bounds.right
                and destination_y >= exclude_bounds.top
                and destination_y < exclude_bounds.bottom
            if not excluded then
            local in_core = core_half > 0
                and x >= -core_half and x < core_half
                and (layout.feature_anchor_up
                    and feature_y >= -(core_half * 2) and feature_y < 0
                    or not layout.feature_anchor_up
                        and feature_y >= -core_half and feature_y < core_half)
            local in_middle = middle_half > 0
                and x >= -middle_half and x < middle_half
                and feature_y >= -middle_half and feature_y < middle_half
            local tile_name = in_core and layout.core_tile or nil
            if not tile_name and layout.rectangles then
                for _, rectangle in ipairs(layout.rectangles) do
                    if x >= rectangle.left and x < rectangle.right
                            and feature_y >= rectangle.top
                            and feature_y < rectangle.bottom then
                        tile_name = rectangle.tile
                        break
                    end
                end
            end
            if not tile_name and railway_corridor_length > 0 then
                local corridor_left = -math.floor(railway_corridor_length / 2)
                local corridor_right = corridor_left + railway_corridor_length
                local in_room = x < corridor_left or x >= corridor_right
                local in_corridor = layout.feature_anchor_up
                    and feature_y >= -(railway_corridor_half * 2)
                    and feature_y < 0
                    or not layout.feature_anchor_up
                        and feature_y >= -railway_corridor_half
                        and feature_y < railway_corridor_half
                if in_room or in_corridor then
                    tile_name = layout.railway_tile
                end
            end
            if not tile_name and chunk_size > 0 and chunk_inner_size > 0 then
                local local_x = x % chunk_size
                local local_y = feature_y % chunk_size
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

local function apply_hospice_tiles(surface, planet_name, floor)
    local surface_left = -math.floor(config.hospice_surface_width / 2)
    local surface_top = -math.floor(config.hospice_surface_height / 2)
    fill_tile_area(
        surface,
        surface_left,
        surface_top,
        surface_left + config.hospice_surface_width,
        surface_top + config.hospice_surface_height,
        'out-of-map'
    )

    local terrain_left = -math.floor(config.hospice_terrain_width / 2)
    local terrain_top = -math.floor(config.hospice_terrain_height / 2)
    local destination_terrain_area = {
        {terrain_left, terrain_top},
        {
            terrain_left + config.hospice_terrain_width,
            terrain_top + config.hospice_terrain_height,
        },
    }
    local sample_offset = floor == 2
        and config.hospice_second_floor_sample_offset or {x = 0, y = 0}
    local source_terrain_area = {
        {
            terrain_left + sample_offset.x,
            terrain_top + sample_offset.y,
        },
        {
            terrain_left + config.hospice_terrain_width + sample_offset.x,
            terrain_top + config.hospice_terrain_height + sample_offset.y,
        },
    }
    local radius = math.max(1, math.ceil(math.max(
        config.hospice_terrain_width,
        config.hospice_terrain_height
    ) / 64) + 1)
    if not clone_planet_tile_area(
        surface,
        planet_name,
        source_terrain_area,
        destination_terrain_area,
        radius,
        sample_offset,
        true
    ) then
        return false
    end

    -- Copy a walkable patch around the floor's sample point to each doorway.
    -- Only the three outer rows extend beyond the 128x128 main terrain.
    local source_doorway = {
        {sample_offset.x - 2, sample_offset.y - 2},
        {sample_offset.x + 2, sample_offset.y + 3},
    }
    local upper_top = config.hospice_upper_entrance_top_y
    if not clone_planet_tile_area(
        surface,
        planet_name,
        source_doorway,
        {{-2, upper_top}, {2, upper_top + 5}},
        1,
        sample_offset
    ) then
        return false
    end
    if floor == 1 then
        local lower_top = config.hospice_lower_entrance_top_y - 2
        if not clone_planet_tile_area(
            surface,
            planet_name,
            source_doorway,
            {{-2, lower_top}, {2, lower_top + 5}},
            1,
            sample_offset
        ) then
            return false
        end
    end
    return true
end

function M.hospice_surface_name(planet_name, floor)
    local prefix = floor == 2
        and config.hospice_second_surface_prefix
        or config.hospice_surface_prefix
    return prefix .. (planet_name or 'nauvis')
end

function M.hospice_floor(surface)
    if not (surface and surface.valid) then return nil end
    local second_prefix = config.hospice_second_surface_prefix
    if surface.name:sub(1, #second_prefix) == second_prefix then
        local name = surface.name:sub(#second_prefix + 1)
        if public_planets[name] then return 2, name end
    end
    local first_prefix = config.hospice_surface_prefix
    if surface.name:sub(1, #first_prefix) == first_prefix then
        local name = surface.name:sub(#first_prefix + 1)
        if public_planets[name] then return 1, name end
    end
    return nil
end

function M.hospice_planet(surface)
    local _, planet_name = M.hospice_floor(surface)
    return planet_name
end

function M.property_planet(surface)
    if not (surface and surface.valid) then return nil end
    local prefix = config.property_surface_prefix
    if surface.name:sub(1, #prefix) ~= prefix then return nil end
    local property_id = tonumber(surface.name:sub(#prefix + 1))
    local property = property_id and storage.properties
        and storage.properties[property_id] or nil
    if not property or property.surface_index ~= surface.index then return nil end
    return property.sample_planet
end

function M.context_planet(surface)
    if not (surface and surface.valid) then return nil end
    if public_planets[surface.name] then return surface.name end
    return M.hospice_planet(surface) or M.property_planet(surface)
end

function M.ensure_hospice(planet_name, floor)
    planet_name = public_planets[planet_name] and planet_name or 'nauvis'
    floor = floor == 2 and 2 or 1
    local surface_name = M.hospice_surface_name(planet_name, floor)
    local surface = game.surfaces[surface_name]
    local created = not (surface and surface.valid)
    if created then
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
    if created and not apply_hospice_tiles(surface, planet_name, floor) then
        log('[un] failed to copy home-planet tiles into refugee camp '
            .. planet_name .. ' floor ' .. floor)
    end
    surface.localised_name = floor == 2 and {
        'un.hospice-name-planet-basement',
        {'space-location-name.' .. planet_name},
    } or {
        'un.hospice-name-planet',
        {'space-location-name.' .. planet_name},
    }
    M.sync_property_environment(surface, nil, planet_name, true)
    local force = factions.of_planet(planet_name)
    if force and force.valid then
        force.set_spawn_position(
            floor == 1 and config.hospice_lower_arrival_position
                or config.hospice_upper_arrival_position,
            surface
        )
    end
    return surface
end

-- Travel and respawn only need an existing destination. Re-running
-- ensure_hospice for every click would rewrite map-gen settings, force chunk
-- generation, and resynchronise every surface property on the main thread.
function M.hospice_surface(planet_name, floor)
    planet_name = public_planets[planet_name] and planet_name or 'nauvis'
    floor = floor == 2 and 2 or 1
    local surface = game.surfaces[M.hospice_surface_name(planet_name, floor)]
    if surface and surface.valid then return surface end
    return M.ensure_hospice(planet_name, floor)
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
    local complete = true
    for floor = 1, 2 do
        local surface = game.surfaces[M.hospice_surface_name(planet_name, floor)]
        if not (surface and surface.valid)
                or not M.sync_property_environment(
                    surface, nil, planet_name, true
                ) then
            complete = false
        end
    end
    return complete
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
        return nil
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
    apply_fixed_property_tiles(
        surface,
        half_width,
        half_height,
        spec.fixed_layout or {fill_tile = TUTORIAL_GRID_NAME},
        nil,
        active_bounds.offset_y
    )
    if not sample_planet then return nil end
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
    M.apply_entrance_tiles(surface, config.property_entrance_top_y)
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
    return surface, sample_planet
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

function M.is_entrance_position(position, top_y)
    return position
        and position.x >= -2 and position.x < 2
        and position.y >= top_y and position.y < top_y + 3
end

local function teleport_to_entrance(player, surface, top_y, center)
    if player.physical_vehicle and player.physical_vehicle.valid then
        return false, 'in-vehicle'
    end
    local position = surface.find_non_colliding_position(
        'character', center, 1, 0.25
    )
    if not position then return false, 'no-safe-position' end
    local in_entrance = M.is_entrance_position(position, top_y)
    if in_entrance then
        storage.entrance_travel_locks[player.index] = {
            surface_index = surface.index,
            top_y = top_y,
        }
    end
    local ok, err = M.teleport_physical(player, position, surface)
    if not ok and in_entrance then
        storage.entrance_travel_locks[player.index] = nil
    end
    return ok, err
end

function M.to_property(player, surface)
    if not M.can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    -- Arrive inside the property, just above the shared doorway layout.
    return teleport_to_entrance(
        player,
        surface,
        config.property_entrance_top_y,
        {x = -0.5, y = -1.5}
    )
end

function M.to_hospice_entrance(player, planet_name, floor, entrance)
    planet_name = planet_name or M.context_planet(player.physical_surface) or 'nauvis'
    floor = floor == 2 and 2 or 1
    entrance = entrance == 'upper' and 'upper' or 'lower'
    local surface = M.hospice_surface(planet_name, floor)
    if not M.can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    local top_y = entrance == 'upper'
        and config.hospice_upper_entrance_top_y
        or config.hospice_lower_entrance_top_y
    local center = entrance == 'upper'
        and config.hospice_upper_arrival_position
        or config.hospice_lower_arrival_position
    return teleport_to_entrance(
        player,
        surface,
        top_y,
        center
    )
end

function M.to_hospice(player, planet_name)
    return M.to_hospice_entrance(player, planet_name, 1, 'lower')
end

function M.to_planet_origin(player, planet_name)
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
    return teleport_to_entrance(player, surface, 0, {x = -0.5, y = 1.5})
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
    return M.hospice_surface(planet_name, 1),
        config.hospice_lower_arrival_position
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
