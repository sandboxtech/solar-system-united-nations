local config = require('config')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')

local M = {}
local TUTORIAL_GRID_NAME = 'tutorial-grid'
local TERRAIN_STYLES = {
    ['dawn-sands'] = {
        floor = {'sand-1', 'sand-2', 'sand-3'},
    },
    ['classic-water'] = {
        floor = {'grass-1', 'grass-2'},
        perimeter = {'water', 'deepwater'},
    },
    ['yumako-soil'] = {
        floor = {'natural-yumako-soil'},
        perimeter = {'wetland-yumako'},
    },
    ['jellynut-soil'] = {
        floor = {'natural-jellynut-soil'},
        perimeter = {'wetland-jellynut'},
    },
    ['oil-ocean'] = {
        floor = {'fulgoran-sand'},
        perimeter = {'oil-ocean-shallow', 'oil-ocean-deep'},
    },
    ['coral-wetland'] = {
        floor = {'lowland-red-vein'},
        perimeter = {'wetland-pink-tentacle', 'wetland-red-tentacle'},
    },
    volcanic = {
        floor = {'volcanic-ash-dark', 'volcanic-ash-light', 'volcanic-ash-flats'},
    },
    ['slime-wetland'] = {
        floor = {'midland-turquoise-bark'},
        perimeter = {
            'wetland-blue-slime',
            'wetland-light-green-slime',
            'wetland-green-slime',
        },
    },
    ['deep-wetland'] = {
        floor = {'highland-dark-rock'},
        perimeter = {'gleba-deep-lake'},
    },
}
local PROPERTY_SCRIPT_TILES = {
    [TUTORIAL_GRID_NAME] = true,
    ['lab-white'] = true,
    ['lab-dark-1'] = true,
    ['lab-dark-2'] = true,
    water = true,
}
for _, style in pairs(TERRAIN_STYLES) do
    for _, name in ipairs(style.floor) do PROPERTY_SCRIPT_TILES[name] = true end
    for _, name in ipairs(style.perimeter or {}) do
        PROPERTY_SCRIPT_TILES[name] = true
    end
end
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

local function regional_tile(names, y, half_height)
    -- Use broad, continuous horizontal regions. Similar tiles never alternate
    -- every few cells, so each floor and perimeter reads as one landscape.
    local relative_y = (y + half_height) / (2 * half_height)
    local index = math.floor(relative_y * #names) + 1
    if index < 1 then index = 1 end
    if index > #names then index = #names end
    return names[index]
end

local function is_script_owned_property_tile(tile)
    if PROPERTY_SCRIPT_TILES[tile.name] then return true end
    local fluid = tile.prototype.fluid
    return fluid and (fluid.name == 'water' or fluid.name == 'heavy-oil')
end

local function property_tile(terrain, x, y, half_width, half_height)
    if x >= -3 and x <= 2 and y >= -3 and y <= 2 then
        return TUTORIAL_GRID_NAME
    end
    local style = TERRAIN_STYLES[terrain] or TERRAIN_STYLES['dawn-sands']
    local margin = config.property_water_margin
    local perimeter = style.perimeter and (
        x < -half_width + margin or x >= half_width - margin
        or y < -half_height + margin or y >= half_height - margin
    )
    if perimeter then
        return regional_tile(style.perimeter, y, half_height)
    end
    return regional_tile(style.floor, y, half_height)
end

local function apply_property_tiles(
        surface, half_width, half_height, terrain, preserve_player_tiles)
    local tiles = {}
    for y = -half_height, half_height - 1 do
        for x = -half_width, half_width - 1 do
            local current = surface.get_tile(x, y)
            local is_core = x >= -3 and x <= 2 and y >= -3 and y <= 2
            if not preserve_player_tiles or is_core
                    or is_script_owned_property_tile(current) then
                tiles[#tiles + 1] = {
                    name = property_tile(terrain, x, y, half_width, half_height),
                    position = {x, y},
                }
            end
        end
    end
    surface.set_tiles(tiles, false, false, true, false)
end

local function apply_tutorial_grid(surface, half_size)
    local tiles = {}
    for y = -half_size, half_size - 1 do
        for x = -half_size, half_size - 1 do
            tiles[#tiles + 1] = {
                name = TUTORIAL_GRID_NAME,
                position = {x, y},
            }
        end
    end
    surface.set_tiles(tiles, false, false, true, false)
end

function M.ensure_hospice()
    local surface = game.surfaces[config.hospice_surface_name]
    if not (surface and surface.valid) then
        surface = game.create_surface(
            config.hospice_surface_name,
            map_gen_settings(config.hospice_surface_size)
        )
    else
        local settings = surface.map_gen_settings
        settings.width = config.hospice_surface_size
        settings.height = config.hospice_surface_size
        surface.map_gen_settings = settings
    end
    ensure_generated(surface, 1)
    if storage.hospice_grid_version ~= 1 then
        apply_tutorial_grid(surface, config.hospice_surface_size / 2)
        storage.hospice_grid_version = 1
    end
    surface.localised_name = {'un.hospice-name'}
    game.forces.player.set_spawn_position({0, 0}, surface)
    return surface
end

function M.create_property_surface(property_id, spec)
    local n = spec.n
    local half_width = spec.shape == 'long' and 2 * n or n
    local half_height = n
    local width = 2 * half_width
    local height = 2 * half_height
    local name = config.property_surface_prefix .. tostring(property_id)
    local surface = game.surfaces[name]
    if not (surface and surface.valid) then
        surface = game.create_surface(name, map_gen_settings(width, height))
    end
    ensure_generated(surface, math.max(1, math.ceil(math.max(width, height) / 64)))
    apply_property_tiles(
        surface,
        half_width,
        half_height,
        spec.terrain or 'dawn-sands'
    )
    surface.always_day = true
    surface.solar_power_multiplier = spec.solar
    surface.localised_name = spec.name or {'un.property-default-name', property_id}
    game.forces.player.set_spawn_position({0, 0}, surface)
    game.forces.player.chart(surface, {
        {-half_width, -half_height},
        {half_width, half_height},
    })
    return surface, half_width, half_height
end

function M.refresh_property_surface(property)
    local surface = game.surfaces[property.surface_name]
    if not (surface and surface.valid) then return false end
    local half_width = math.floor((property.width or property.size or 0) / 2)
    local half_height = math.floor((property.height or property.size or 0) / 2)
    if half_width < 1 or half_height < 1 then return false end
    apply_property_tiles(
        surface,
        half_width,
        half_height,
        property.terrain or config.property_terrain_by_theme[property.theme]
            or 'dawn-sands',
        true
    )
    return true
end

local function safe_position(surface, center)
    surface.request_to_generate_chunks(center, 1)
    surface.force_generate_chunk_requests()
    return surface.find_non_colliding_position('character', center, 64, 1)
end

local function can_start_public_travel(surface)
    if not (surface and surface.valid) then return false end
    if public_planets[surface.name] then return true end
    if surface.name == config.hospice_surface_name then return true end
    return surface.name:sub(1, #config.property_surface_prefix)
        == config.property_surface_prefix
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
    if not can_start_public_travel(player.physical_surface) then
        return false, 'travel-restricted'
    end
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.to_hospice(player)
    return M.teleport(player, M.ensure_hospice())
end

function M.to_planet(player)
    local source = player.physical_surface
    if not can_start_public_travel(source) then
        return false, 'travel-restricted'
    end
    local dropoff = linked_inventory.get_active_dropoff(player.index)
    if dropoff then
        return M.teleport_near(player, dropoff.surface, dropoff.position, false)
    end

    local surface = game.surfaces.nauvis
    if not (surface and surface.valid) then return false, 'surface-missing' end
    return M.teleport_near(player, surface, {0, 0}, false)
end

function M.suicide(player)
    local character = player.character
    if not (character and character.valid) then
        for _, candidate in pairs(player.get_associated_characters()) do
            if candidate.valid then character = candidate; break end
        end
    end
    if not (character and character.valid) then return false, 'no-character' end
    return character.die(game.forces.neutral)
end

local function respawn_destination(player)
    local dropoff = linked_inventory.get_active_dropoff(player.index)
    if dropoff then return dropoff.surface, dropoff.position end
    return M.ensure_hospice(), {0, 0}
end

events.on(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then M.to_hospice(player) end
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
