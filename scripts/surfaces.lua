local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')

local M = {}
local TUTORIAL_GRID_NAME = 'tutorial-grid'
local public_planets = {}
for _, name in ipairs(config.public_planets) do public_planets[name] = true end
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

local function sample_planet_name(property_id, requested)
    if public_planets[requested] then return requested end
    local names = config.property_sample_planets
    return names[(property_id - 1) % #names + 1]
end

local function ensure_planet_surface(name)
    local surface = game.surfaces[name]
    if surface and surface.valid then return surface end
    local planet = game.planets[name]
    if not (planet and planet.valid) then return nil end
    return planet.create_surface()
end

local function sample_center(source, property_id, half_width, half_height)
    local settings = source.map_gen_settings
    local map_width = tonumber(settings.width) or 0
    local map_height = tonumber(settings.height) or 0
    if map_width > 0 and map_height > 0 then
        local usable_x = math.max(0, math.floor(map_width / 2 - half_width - 64))
        local usable_y = math.max(0, math.floor(map_height / 2 - half_height - 64))
        local x = usable_x > 0
            and ((property_id * 977) % (2 * usable_x + 1) - usable_x) or 0
        local y = usable_y > 0
            and ((property_id * 1597) % (2 * usable_y + 1) - usable_y) or 0
        return {x = x, y = y}
    end
    return {
        x = 4096 + (property_id * 977) % 2048,
        y = ((property_id % 2 == 0) and -1 or 1)
            * (4096 + (property_id * 1597) % 2048),
    }
end

local function core_half_size(half_width, half_height)
    if half_width == half_height then return half_width / 2 end
    return math.min(half_width, half_height)
end

local function in_core(x, y, core_half)
    return x >= -core_half and x < core_half
        and y >= -core_half and y < core_half
end

local function copy_sample_tiles(
        source, center, destination, half_width, half_height, core_half)
    local tiles = {}
    for y = -half_height, half_height - 1 do
        for x = -half_width, half_width - 1 do
            tiles[#tiles + 1] = {
                name = in_core(x, y, core_half) and TUTORIAL_GRID_NAME
                    or source.get_tile(center.x + x, center.y + y).name,
                position = {x, y},
            }
        end
    end
    -- Let Factorio correct neighbouring tile transitions so copied biomes keep
    -- their native smooth borders instead of exposing raw stair-step edges.
    destination.set_tiles(tiles, true, false, true, false)
end

local function is_rock(entity)
    if entity.type ~= 'simple-entity'
            and entity.type ~= 'simple-entity-with-force' then
        return false
    end
    local subgroup = entity.prototype.subgroup
    return (subgroup and subgroup.name == 'rocks')
        or entity.name:find('rock', 1, true) ~= nil
end

local function copy_sample_entities(
        source, center, destination, half_width, half_height, core_half)
    local entities = source.find_entities_filtered{
        area = {
            {center.x - half_width, center.y - half_height},
            {center.x + half_width, center.y + half_height},
        },
        type = {'tree', 'simple-entity', 'simple-entity-with-force'},
    }
    table.sort(entities, function(a, b)
        if a.position.y ~= b.position.y then return a.position.y < b.position.y end
        if a.position.x ~= b.position.x then return a.position.x < b.position.x end
        return a.name < b.name
    end)
    for _, entity in ipairs(entities) do
        if entity.valid and (entity.type == 'tree' or is_rock(entity)) then
            local position = {
                x = entity.position.x - center.x,
                y = entity.position.y - center.y,
            }
            if not in_core(position.x, position.y, core_half) then
                destination.create_entity{
                    name = entity.name,
                    position = position,
                    direction = entity.direction,
                    force = entity.force,
                    snap_to_grid = false,
                    raise_built = false,
                }
            end
        end
    end
end

local function apply_natural_sample(surface, property_id, half_width, half_height,
        requested_planet)
    local planet_name = sample_planet_name(property_id, requested_planet)
    local source = ensure_planet_surface(planet_name)
    if not source then return nil, nil end
    local center = sample_center(source, property_id, half_width, half_height)
    local radius = math.max(
        1,
        math.ceil(math.max(half_width, half_height) / 32) + 1
    )
    source.request_to_generate_chunks(center, radius)
    source.force_generate_chunk_requests()
    local core_half = core_half_size(half_width, half_height)
    copy_sample_tiles(
        source, center, surface, half_width, half_height, core_half
    )
    copy_sample_entities(
        source, center, surface, half_width, half_height, core_half
    )
    return planet_name, center
end

local function apply_property_special_tiles(surface, half_width, half_height, spec)
    local rows = tonumber(spec.top_tile_rows) or 0
    local split_rows = tonumber(spec.top_split_rows) or 0
    if rows <= 0 and split_rows <= 0 then return end
    local tiles = {}
    for y = -half_height, -half_height + math.max(rows, split_rows) - 1 do
        for x = -half_width, half_width - 1 do
            local name
            if y < -half_height + split_rows then
                name = x < 0 and spec.top_left_tile or spec.top_right_tile
            elseif y < -half_height + rows then
                name = spec.top_tile
            end
            if name then
                tiles[#tiles + 1] = {name = name, position = {x, y}}
            end
        end
    end
    if #tiles > 0 then surface.set_tiles(tiles, true, false, true, false) end
end

local function apply_fixed_property_tiles(surface, half_width, half_height, layout)
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
                position = {x, y},
            }
        end
    end
    surface.set_tiles(tiles, true, false, true, false)
end

local function apply_hospice_tiles(surface, planet_name)
    local half_width = config.hospice_surface_width / 2
    local half_height = config.hospice_surface_height / 2
    local core_half = config.hospice_core_size / 2
    local border = config.hospice_liquid_border_width
    local planet_tiles = config.hospice_tiles[planet_name]
    local tiles = {}
    for y = -half_height, half_height - 1 do
        for x = -half_width, half_width - 1 do
            local in_liquid_border = x < -half_width + border
                or x >= half_width - border
                or y < -half_height + border
                or y >= half_height - border
            local tile_name = in_core(x, y, core_half)
                and TUTORIAL_GRID_NAME
                or in_liquid_border and planet_tiles.liquid
                or planet_tiles.land
            tiles[#tiles + 1] = {
                name = tile_name,
                position = {x, y},
            }
        end
    end
    -- Submit the complete layout in one batch, then let Factorio correct all
    -- neighbouring tiles so liquids receive their native coast transitions.
    surface.set_tiles(tiles, true, false, true, false)
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

function M.sync_property_environment(
        surface, min_brightness, planet_name, use_planet_solar)
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
        pcall(function() surface.set_property(name, value) end)
    end
    surface.daytime_parameters = config.property_daytime_parameters
    surface.ticks_per_day = math.max(1, math.floor(
        (defaults['day-night-cycle']
            or prototypes.surface_property['day-night-cycle'].default_value)
            + 0.5
    ))
    surface.always_day = false
    surface.freeze_daytime = false
    surface.solar_power_multiplier = use_planet_solar
        and (defaults['solar-power']
            or prototypes.surface_property['solar-power'].default_value) / 100
        or config.property_solar_multiplier
    surface.min_brightness = min_brightness or config.property_min_brightness
    if use_planet_solar then
        local planet_surface = game.surfaces[planet_name or 'nauvis']
        if planet_surface and planet_surface.valid then
            surface.daytime = planet_surface.daytime
        end
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
                property.terrain_planet or property.sample_planet
            )
        end
    end
end

function M.create_property_surface(property_id, spec)
    local width = spec.width
    local height = spec.height
    local half_width = width / 2
    local half_height = height / 2
    local requested_planet = sample_planet_name(
        property_id,
        spec.terrain_planet or spec.sample_planet
    )
    local reset = storage.public_planet_resets
        and storage.public_planet_resets[requested_planet]
    if reset and reset.state ~= 'open' then
        return nil, nil, nil, nil, nil
    end
    local name = config.property_surface_prefix .. tostring(property_id)
    local surface = game.surfaces[name]
    if not (surface and surface.valid) then
        surface = game.create_surface(name, map_gen_settings(width, height))
    end
    ensure_generated(surface, math.max(1, math.ceil(math.max(width, height) / 64)))
    local sample_planet, sample_position
    if spec.fixed_layout then
        sample_planet = requested_planet
        apply_fixed_property_tiles(
            surface, half_width, half_height, spec.fixed_layout
        )
    else
        sample_planet, sample_position = apply_natural_sample(
            surface,
            property_id,
            half_width,
            half_height,
            requested_planet
        )
    end
    if not sample_planet then return nil, nil, nil, nil, nil end
    apply_property_special_tiles(surface, half_width, half_height, spec)
    M.sync_property_environment(surface, nil, sample_planet)
    surface.localised_name = spec.name or {'un.property-default-name', property_id}
    local force = factions.of_planet(spec.sample_planet)
    if force and force.valid then
        force.set_spawn_position({0, 0}, surface)
        force.chart(surface, {
        {-half_width, -half_height},
        {half_width, half_height},
        })
    end
    return surface, half_width, half_height, sample_planet, sample_position
end

local function safe_position(surface, center)
    surface.request_to_generate_chunks(center, 3)
    surface.force_generate_chunk_requests()
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

function M.teleport_near(player, surface, center, allow_vehicle)
    if not (surface and surface.valid) then return false, 'surface-missing' end
    if not allow_vehicle and player.vehicle and player.vehicle.valid then
        return false, 'in-vehicle'
    end
    local position = safe_position(surface, center)
    if not position then position = {0, 2} end
    return player.teleport(position, surface)
end

function M.teleport(player, surface)
    if not M.can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.to_hospice(player, planet_name)
    planet_name = planet_name or M.context_planet(player.physical_surface) or 'nauvis'
    return M.teleport(player, M.ensure_hospice(planet_name))
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
    if player.vehicle and player.vehicle.valid then return false, 'in-vehicle' end
    local preferred_center = recorded_center(surface, planet_name, return_record)
    if preferred_center then
        local position = safe_position(surface, preferred_center)
        if position then return player.teleport(position, surface) end
    end
    local radius = config.public_planet_arrival_radius
    surface.request_to_generate_chunks({0, 0}, math.ceil(radius / 32) + 1)
    surface.force_generate_chunk_requests()
    for _ = 1, 32 do
        local center = {
            x = weighted_arrival_axis(radius),
            y = weighted_arrival_axis(radius),
        }
        local position = surface.find_non_colliding_position(
            'character',
            center,
            8,
            1
        )
        if position and math.abs(position.x) < radius
                and math.abs(position.y) < radius then
            return player.teleport(position, surface)
        end
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
    return M.ensure_hospice(planet_name), {0, 0}
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
