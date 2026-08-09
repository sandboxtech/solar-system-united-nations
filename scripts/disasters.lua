local config = require('config')
local events = require('scripts.events')
local linked_inventory = require('scripts.linked_inventory')
local scheduler = require('scripts.scheduler')
local settings = require('scripts.settings')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

local PLANET_TRAITS = {
    nauvis = {
        {id = 'nauvis-iron-rich', kind = 'control', controls = {'iron-ore'},
            frequency = 4, size = 4, richness = 16},
        {id = 'nauvis-copper-rich', kind = 'control', controls = {'copper-ore'},
            frequency = 4, size = 4, richness = 16},
        {id = 'nauvis-oil-rich', kind = 'control', controls = {'crude-oil'},
            frequency = 2, size = 4, richness = 16},
        {id = 'nauvis-uranium-rich', kind = 'control', controls = {'uranium-ore'},
            frequency = 2, size = 2, richness = 16},
        {id = 'nauvis-lush', kind = 'climate', moisture = 1},
        {id = 'nauvis-swarm', kind = 'category', category = 'enemy',
            frequency = 4, size = 4, richness = 1},
        {id = 'nauvis-bright-sun', kind = 'solar', factor = 10},
        {id = 'nauvis-long-day', kind = 'day', factor = 10},
    },
    vulcanus = {
        {id = 'vulcanus-tungsten-rich', kind = 'control',
            controls = {'tungsten_ore'}, frequency = 4, size = 4, richness = 16},
        {id = 'vulcanus-coal-rich', kind = 'control',
            controls = {'vulcanus_coal'},
            frequency = 4, size = 4, richness = 16},
        {id = 'vulcanus-calcite-rich', kind = 'control', controls = {'calcite'},
            frequency = 4, size = 4, richness = 16},
        {id = 'vulcanus-acid-rich', kind = 'control',
            controls = {'sulfuric_acid_geyser'},
            frequency = 4, size = 4, richness = 16},
        {id = 'vulcanus-fractured', kind = 'cliffs', interval = 0.1,
            richness = 10},
        {id = 'vulcanus-hot', kind = 'climate', temperature = 50},
        {id = 'vulcanus-bright-sun', kind = 'solar', factor = 10},
        {id = 'vulcanus-long-day', kind = 'day', factor = 10},
    },
    gleba = {
        {id = 'gleba-lush', kind = 'category', category = 'terrain',
            frequency = 4, size = 10, richness = 10},
        {id = 'gleba-wet', kind = 'climate', group = 'gleba-moisture',
            moisture = 1},
        {id = 'gleba-dry', kind = 'climate', group = 'gleba-moisture',
            moisture = -1},
        {id = 'gleba-warm', kind = 'climate', temperature = 50},
        {id = 'gleba-enemies', kind = 'category', category = 'enemy',
            frequency = 4, size = 4, richness = 1},
        {id = 'gleba-broad-biomes', kind = 'climate-frequency',
            moisture_frequency = 0.1},
    },
    fulgora = {
        {id = 'fulgora-scrap-rich', kind = 'control', controls = {'scrap'},
            frequency = 4, size = 4, richness = 16},
        {id = 'fulgora-resources', kind = 'category', category = 'resource',
            frequency = 2, size = 4, richness = 8},
        {id = 'fulgora-large-islands', kind = 'category', category = 'terrain',
            group = 'fulgora-islands', frequency = 0.1, size = 10,
            richness = 1},
        {id = 'fulgora-small-islands', kind = 'category', category = 'terrain',
            group = 'fulgora-islands', frequency = 10, size = 0.1,
            richness = 1},
        {id = 'fulgora-dry', kind = 'climate', moisture = -1},
        {id = 'fulgora-fractured', kind = 'cliffs', interval = 0.1,
            richness = 10},
        {id = 'fulgora-solar-storm', kind = 'solar', factor = 10},
        {id = 'fulgora-long-day', kind = 'day', factor = 10},
    },
    aquilo = {
        {id = 'aquilo-lithium-rich', kind = 'control',
            controls = {'lithium_brine'}, frequency = 4, size = 4, richness = 16},
        {id = 'aquilo-fluorine-rich', kind = 'control',
            controls = {'fluorine_vent'}, frequency = 4, size = 4, richness = 16},
        {id = 'aquilo-resources', kind = 'category', category = 'resource',
            frequency = 2, size = 4, richness = 8},
        {id = 'aquilo-broad-ice', kind = 'category', category = 'terrain',
            frequency = 0.1, size = 10, richness = 1},
        {id = 'aquilo-deep-cold', kind = 'climate', temperature = -50},
        {id = 'aquilo-broad-climate', kind = 'climate-frequency',
            moisture_frequency = 0.1},
        {id = 'aquilo-pale-sun', kind = 'solar', factor = 0.1},
    },
}

local STATISTIC_GETTERS = {
    'get_item_production_statistics',
    'get_fluid_production_statistics',
    'get_kill_count_statistics',
    'get_entity_build_count_statistics',
}

local function planet_label(name)
    return {'', '[planet=' .. name .. '] ', {'space-location-name.' .. name}}
end

local function ensure_surface(name)
    local surface = game.surfaces[name]
    if surface and surface.valid then return surface end
    local planet = game.planets[name]
    if not (planet and planet.valid) then return nil end
    return planet.create_surface()
end

local function roll_period_ticks()
    local random = math.random()
    local hours = config.public_planet_reset_min_hours
        + config.public_planet_reset_random_hours * random * random
    return math.floor(hours * config.ticks_per_hour + 0.5)
end

local function ensure_record(name)
    state.ensure()
    local records = storage.public_planet_resets
    local record = records[name]
    local surface = ensure_surface(name)
    if not record then
        local offset = (config.public_planet_initial_offset_minutes[name] or 0)
            * config.ticks_per_minute
        record = {
            state = 'open',
            round = 0,
            period_ticks = roll_period_ticks(),
            warned = {},
        }
        record.next_tick = game.tick + record.period_ticks + offset
        records[name] = record
    end
    if record.state == nil then record.state = 'open' end
    if record.round == nil then record.round = 0 end
    if record.warned == nil then record.warned = {} end
    if record.period_ticks == nil then
        record.period_ticks = roll_period_ticks()
    end
    if record.next_tick == nil and record.state == 'open'
            and settings.get('planet_resets_enabled') then
        record.next_tick = game.tick + record.period_ticks
    end
    if surface and surface.valid then
        if record.base_solar == nil then
            record.base_solar = surface.solar_power_multiplier
        end
        if record.base_day == nil then record.base_day = surface.ticks_per_day end
    end
    return record, surface
end

local function evacuate_player(player, target_surface)
    local hospice = surfaces.ensure_hospice(target_surface.name)
    if player.connected and player.controller_type == defines.controllers.remote
            and player.surface == target_surface then
        pcall(function() player.exit_remote_view() end)
        -- In 2.0 exit_remote_view can legitimately fail while the physical
        -- controller is in a rocket or on a platform. Keep that physical
        -- controller intact and redirect only the remote controller.
        if player.controller_type == defines.controllers.remote
                and player.surface == target_surface then
            pcall(function()
                player.set_controller{
                    type = defines.controllers.remote,
                    surface = hospice,
                    position = {0, 0},
                }
            end)
        end
    end
    if player.physical_surface == target_surface then
        local moved = false
        pcall(function()
            if player.connected then player.exit_remote_view() end
            if player.vehicle and player.vehicle.valid then player.driving = false end
            moved = surfaces.teleport_near(
                player,
                hospice,
                {0, 0},
                true
            )
        end)
        if not moved then
            local character = player.character
            if character and character.valid then
                pcall(function()
                    character.teleport({0, 2}, hospice)
                end)
            end
        end
    end

    -- A player can retain more than one associated character. Move any body
    -- that was not controlled by LuaPlayer::teleport as well.
    for _, character in pairs(player.get_associated_characters()) do
        if character.valid and character.surface == target_surface then
            pcall(function()
                character.teleport({0, 2}, hospice)
            end)
        end
    end
end

local function evacuate(surface)
    for _, player in pairs(game.players) do
        evacuate_player(player, surface)
    end
end

local function choose(list)
    return list[math.random(1, #list)]
end

local function power_of_two(spread)
    return 2 ^ (-spread + math.random() * spread * 2)
end

local function sorted_control_names(map_settings)
    local names = {}
    for name in pairs(map_settings.autoplace_controls or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function randomize_autoplace(map_settings, record)
    local enemy_control = false
    record.autoplace = {}
    for _, name in ipairs(sorted_control_names(map_settings)) do
        local prototype = prototypes.autoplace_control[name]
        local control = map_settings.autoplace_controls[name]
        local category = prototype and prototype.category
        if category == 'resource' then
            local base = config.public_planet_resource_base
            control.frequency = base.frequency
                * power_of_two(config.public_planet_resource_spread)
            control.size = base.size
                * power_of_two(config.public_planet_resource_spread)
            control.richness = base.richness
                * power_of_two(config.public_planet_resource_spread)
        elseif category == 'enemy' then
            enemy_control = true
            control.frequency = power_of_two(config.public_planet_enemy_spread)
            control.size = power_of_two(config.public_planet_enemy_spread)
        elseif category == 'terrain' then
            control.frequency = (control.frequency or 1)
                * power_of_two(config.public_planet_terrain_spread)
            control.size = (control.size or 1)
                * power_of_two(config.public_planet_terrain_spread)
            control.richness = (control.richness or 1)
                * power_of_two(config.public_planet_terrain_spread)
        end
        record.autoplace[name] = {
            frequency = control.frequency,
            size = control.size,
            richness = control.richness,
        }
    end

    if enemy_control then
        map_settings.starting_area = (map_settings.starting_area or 1)
            * power_of_two(config.public_planet_enemy_spread)
    end

    local cliffs = map_settings.cliff_settings
    if cliffs then
        cliffs.cliff_elevation_interval = math.max(
            1,
            (cliffs.cliff_elevation_interval or 40)
                * power_of_two(config.public_planet_cliff_spread)
        )
        cliffs.richness = (cliffs.richness or 1)
            * power_of_two(config.public_planet_cliff_spread)
    end
end

local function randomize_climate(name, map_settings, record)
    local expressions = map_settings.property_expression_names or {}
    record.climate = {
        moisture_bias = (math.random() - math.random()) * 0.5,
        aux_bias = (math.random() - math.random()) * 0.5,
        temperature_bias = (math.random() - math.random()) * 20,
        moisture_frequency = power_of_two(1),
    }
    expressions['control:moisture:bias'] = tostring(record.climate.moisture_bias)
    expressions['control:aux:bias'] = tostring(record.climate.aux_bias)
    expressions['control:temperature:bias'] = tostring(
        record.climate.temperature_bias
    )
    expressions['control:moisture:frequency'] = tostring(
        record.climate.moisture_frequency
    )
    if name == 'aquilo' then
        record.climate.aquilo_segmentation = power_of_two(3)
        expressions.aquilo_segmentation_multiplier = tostring(
            record.climate.aquilo_segmentation
        )
    end
    map_settings.property_expression_names = expressions
end

local function randomize_demolishers(map_settings, record)
    local territory = map_settings.territory_settings
    if not (territory and territory.units and #territory.units > 0) then return end
    territory.minimum_territory_size = math.max(
        1,
        math.floor((territory.minimum_territory_size or 10)
            * power_of_two(2) + 0.5)
    )
    local roll = math.random()
    if roll < 0.05 then
        territory.minimum_territory_size = 4294967295
        record.demolisher_tiers = 0
    elseif roll < 0.25 then
        territory.units = {'small-demolisher'}
        record.demolisher_tiers = 1
    elseif roll < 0.55 then
        territory.units = {'small-demolisher', 'medium-demolisher'}
        record.demolisher_tiers = 2
    else
        record.demolisher_tiers = #territory.units
    end
end

local function multiply_control(control, trait)
    control.frequency = (control.frequency or 1) * (trait.frequency or 1)
    control.size = (control.size or 1) * (trait.size or 1)
    control.richness = (control.richness or 1) * (trait.richness or 1)
end

local function apply_trait(map_settings, record, trait)
    local controls = map_settings.autoplace_controls or {}
    local applied = false
    if trait.kind == 'control' then
        for _, name in ipairs(trait.controls) do
            local control = controls[name]
            if control then
                multiply_control(control, trait)
                applied = true
                break
            end
        end
    elseif trait.kind == 'category' then
        for _, name in ipairs(sorted_control_names(map_settings)) do
            local prototype = prototypes.autoplace_control[name]
            if prototype and prototype.category == trait.category then
                multiply_control(controls[name], trait)
                applied = true
            end
        end
    elseif trait.kind == 'cliffs' then
        local cliffs = map_settings.cliff_settings
        if cliffs then
            cliffs.cliff_elevation_interval = math.max(
                1,
                (cliffs.cliff_elevation_interval or 40) * trait.interval
            )
            cliffs.richness = (cliffs.richness or 1) * trait.richness
            applied = true
        end
    elseif trait.kind == 'climate' then
        record.climate.moisture_bias = record.climate.moisture_bias
            + (trait.moisture or 0)
        record.climate.temperature_bias = record.climate.temperature_bias
            + (trait.temperature or 0)
        local expressions = map_settings.property_expression_names or {}
        expressions['control:moisture:bias'] = tostring(
            record.climate.moisture_bias
        )
        expressions['control:temperature:bias'] = tostring(
            record.climate.temperature_bias
        )
        map_settings.property_expression_names = expressions
        applied = true
    elseif trait.kind == 'climate-frequency' then
        record.climate.moisture_frequency = record.climate.moisture_frequency
            * trait.moisture_frequency
        local expressions = map_settings.property_expression_names or {}
        expressions['control:moisture:frequency'] = tostring(
            record.climate.moisture_frequency
        )
        map_settings.property_expression_names = expressions
        applied = true
    elseif trait.kind == 'solar' then
        record.solar_factor = record.solar_factor * trait.factor
        applied = true
    elseif trait.kind == 'day' then
        record.day_factor = record.day_factor * trait.factor
        applied = true
    end
    return applied
end

local function roll_traits(name, map_settings, record)
    local pool = PLANET_TRAITS[name] or {}
    local order = {}
    for index = 1, #pool do order[index] = index end
    for index = #order, 2, -1 do
        local other = math.random(1, index)
        order[index], order[other] = order[other], order[index]
    end
    record.traits = {}
    local selected_groups = {}
    for _, index in ipairs(order) do
        local trait = pool[index]
        if (not trait.group or not selected_groups[trait.group])
                and apply_trait(map_settings, record, trait) then
            record.traits[#record.traits + 1] = trait.id
            if trait.group then selected_groups[trait.group] = true end
            if #record.traits == 3 then break end
        end
    end
end

local function prepare_new_round(name, surface, record)
    local planet = game.planets[name]
    if planet and planet.valid then planet.reset_map_gen_settings() end
    local map_settings = surface.map_gen_settings
    map_settings.seed = math.random(1, 2147483647)
    record.solar_factor = choose(config.public_planet_solar_factors)
    record.day_factor = choose(config.public_planet_day_factors)
    randomize_autoplace(map_settings, record)
    randomize_climate(name, map_settings, record)
    randomize_demolishers(map_settings, record)
    roll_traits(name, map_settings, record)
    surface.map_gen_settings = map_settings

    record.round = record.round + 1
    record.seed = map_settings.seed
    record.evolution = name == 'nauvis' and math.random() ^ 2 or nil
    record.min_brightness = math.random() * 0.2
    record.peaceful = math.random() < config.public_planet_peaceful_chance
    local half_day = 0.1 + math.random() * 0.3
    local evening = half_day + (0.5 - half_day)
        * (0.4 + math.random() * 0.5)
    record.daytime_parameters = {
        dusk = half_day,
        evening = evening,
        morning = 1 - evening,
        dawn = 1 - half_day,
    }
end

local function apply_round_environment(name, surface, record)
    pcall(function()
        surface.solar_power_multiplier = (record.base_solar or 1)
            * (record.solar_factor or 1)
    end)
    pcall(function()
        surface.ticks_per_day = math.max(
            1,
            math.floor((record.base_day or surface.ticks_per_day)
                * (record.day_factor or 1))
        )
    end)
    pcall(function()
        surface.daytime_parameters = record.daytime_parameters
        surface.min_brightness = record.min_brightness
        surface.peaceful_mode = record.peaceful == true
    end)
    if name == 'nauvis' and record.evolution then
        game.forces.enemy.set_evolution_factor(record.evolution, surface)
    end
end

local function begin_reset(name, surface, record)
    record.state = 'clearing'
    record.next_tick = nil
    record.warned = {}
    record.surface_index = surface.index
    record.clear_started_tick = game.tick
    game.print({'un.planet-reset-started', planet_label(name)})

    evacuate(surface)
    linked_inventory.clear_surface_dropoffs(name)
    local ok, err = pcall(function()
        prepare_new_round(name, surface, record)
        surface.clear(true)
    end)
    if not ok then
        record.state = 'open'
        record.next_tick = game.tick + config.ticks_per_minute
        record.clear_started_tick = nil
        log('[un] failed to start reset for ' .. name .. ': ' .. tostring(err))
        for _, player in pairs(game.connected_players) do
            if player.admin then
                player.print({'un.planet-reset-failed', planet_label(name)})
            end
        end
    end
end

local function clear_statistics(surface)
    for _, force in pairs(game.forces) do
        if force and force.valid then
            for _, getter in ipairs(STATISTIC_GETTERS) do
                local ok, err = pcall(function()
                    force[getter](surface).clear()
                end)
                if not ok then
                    log('[un] failed to clear ' .. getter .. ' on '
                        .. surface.name .. ': ' .. tostring(err))
                end
            end
        end
    end
end

local function finish_reset(name, surface, record)
    clear_statistics(surface)
    apply_round_environment(name, surface, record)
    surfaces.sync_all_property_environments()
    game.forces.player.set_spawn_position({0, 0}, surface)
    surface.request_to_generate_chunks({0, 0}, 1)
    surface.force_generate_chunk_requests()

    record.state = 'open'
    record.surface_index = surface.index
    record.clear_started_tick = nil
    record.period_ticks = roll_period_ticks()
    if settings.get('planet_resets_enabled') then
        record.next_tick = game.tick + record.period_ticks
        record.paused_left_ticks = nil
    else
        record.next_tick = nil
        record.paused_left_ticks = record.period_ticks
    end
    record.warned = {}
    game.print({
        'un.planet-reset-finished',
        planet_label(name),
        math.floor((record.solar_factor or 1) * 100 + 0.5),
        math.floor((record.day_factor or 1) * 100 + 0.5),
        string.format('%.2f', record.min_brightness or 0),
        record.peaceful and {'un.yes'} or {'un.no'},
    })
end

function M.apply_global_settings()
    game.difficulty_settings.technology_price_multiplier =
        settings.get('technology_price_multiplier')
    game.difficulty_settings.spoil_time_modifier =
        settings.get('spoil_time_modifier')
    game.map_settings.asteroids.spawning_rate =
        settings.get('asteroid_spawning_rate')
end

function M.is_open(name)
    local record = storage.public_planet_resets
        and storage.public_planet_resets[name]
    return not record or record.state == 'open'
end

function M.list()
    state.ensure()
    local result = {}
    for _, name in ipairs(config.public_planets) do
        local record = storage.public_planet_resets[name]
        if not record then record = ensure_record(name) end
        result[#result + 1] = {
            name = name,
            state = record.state,
            round = record.round or 0,
            paused = record.state == 'open'
                and not settings.get('planet_resets_enabled'),
            left_ticks = record.state == 'open' and record.next_tick
                and math.max(0, record.next_tick - game.tick)
                or record.paused_left_ticks,
            traits = record.traits or {},
        }
    end
    return result
end

function M.apply_enabled(enabled)
    for _, name in ipairs(config.public_planets) do
        local record = storage.public_planet_resets[name]
        if not record then record = ensure_record(name) end
        if enabled then
            if record.state == 'open' and not record.next_tick then
                record.next_tick = game.tick
                    + (record.paused_left_ticks or record.period_ticks
                        or roll_period_ticks())
            end
            record.paused_left_ticks = nil
        elseif record.state == 'open' and record.next_tick then
            record.paused_left_ticks = math.max(0, record.next_tick - game.tick)
            record.next_tick = nil
        end
    end
end

function M.ensure()
    M.apply_global_settings()
    for _, name in ipairs(config.public_planets) do
        local record, surface = ensure_record(name)
        if record.round == 0 and surface and surface.valid then
            prepare_new_round(name, surface, record)
            apply_round_environment(name, surface, record)
        end
    end
    if not settings.get('planet_resets_enabled') then M.apply_enabled(false) end
end

local function check_resets()
    if not settings.get('planet_resets_enabled') then return end
    for _, name in ipairs(config.public_planets) do
        local record, surface = ensure_record(name)
        if record.state == 'open' and record.next_tick then
            local left = record.next_tick - game.tick
            for _, minutes in ipairs(config.public_planet_warning_minutes) do
                local threshold = minutes * config.ticks_per_minute
                if left <= threshold and left > 0 and not record.warned[minutes] then
                    record.warned[minutes] = true
                    game.print({'un.planet-reset-warning', planet_label(name), minutes})
                end
            end
            if left <= 0 and surface and surface.valid then
                begin_reset(name, surface, record)
            end
        end
    end
end

events.on(defines.events.on_surface_cleared, function(event)
    local surface = game.surfaces[event.surface_index]
    if not (surface and surface.valid) then return end
    local record = storage.public_planet_resets
        and storage.public_planet_resets[surface.name]
    if not (record and record.state == 'clearing'
            and record.surface_index == event.surface_index) then
        return
    end
    finish_reset(surface.name, surface, record)
end)

events.on(defines.events.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local surface = player.physical_surface
    if surface and not M.is_open(surface.name) then
        evacuate_player(player, surface)
        player.print({'un.planet-reset-closed', planet_label(surface.name)})
    end
end)

scheduler.every(config.public_planet_check_ticks, check_resets)

return M
