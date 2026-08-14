return function(M)
    local function property_build_type(spec)
        spec.base_width = spec.base_width or 32
        spec.width_per_level = spec.width_per_level or 0.5
        spec.height = spec.height or 32
        spec.height_per_level = spec.height_per_level or 0.2
        spec.max_width = spec.max_width or 256
        spec.max_height = spec.max_height or 256
        spec.initial_price_multiplier = spec.initial_price_multiplier or 1
        spec.base_decay_hours = spec.base_decay_hours or 10
        spec.decay_hours_per_level = spec.decay_hours_per_level or 1
        spec.base_lifetime_hours = spec.base_lifetime_hours or 100
        spec.lifetime_hours_per_level = spec.lifetime_hours_per_level or 1
        if spec.expandable == nil then spec.expandable = true end
        return spec
    end

    local function upper_band(tile)
        return {
            {
                tile = tile,
                direction = 'full',
                top = -2,
                thickness = 3,
            },
        }
    end

    M.property_build_types = {
        property_build_type{
            pack = 'automation-science-pack',
            key = 'shelter',
            base_width = 32,
            width_per_level = 0.5,
            height = 32,
            height_per_level = 0.2,
            base_decay_hours = 2,
            decay_hours_per_level = 0.1,
            base_lifetime_hours = 100,
            lifetime_hours_per_level = 1,
            fixed_layout = {
                fill_tile = 'tutorial-grid',
            },
        },
        property_build_type{
            pack = 'logistic-science-pack',
            key = 'cottage',
            automatic_trade = 'balance',
            base_width = 32,
            width_per_level = 0.5,
            height = 32,
            height_per_level = 0.2,
            initial_price_multiplier = 2,
            base_decay_hours = 6,
            decay_hours_per_level = 0.2,
            base_lifetime_hours = 100,
            lifetime_hours_per_level = 1,
            fixed_layout = {
                fill_tile = 'grass-1',
            },
        },
        property_build_type{
            pack = 'military-science-pack',
            key = 'secure-cottage',
            initial_price_multiplier = 10,
            base_decay_hours = 100,
            decay_hours_per_level = 10,
            crime_chance_multiplier = 0.1,
            fixed_layout = {
                fill_tile = 'tutorial-grid',
            },
        },
        property_build_type{
            pack = 'chemical-science-pack',
            key = 'shore-cottage',
            initial_price_multiplier = 3,
            terrain_planet = 'nauvis',
            fixed_layout = {
                fill_tile = 'tutorial-grid',
            },
            lower_half_out_of_map = true,
            special_areas = upper_band('water'),
        },
        property_build_type{
            pack = 'production-science-pack',
            key = 'rail-estate',
            base_width = 512,
            width_per_level = 0.5,
            max_width = 1024,
            height = 64,
            height_per_level = 0.2,
            max_height = 320,
            initial_price_multiplier = 4,
            fixed_layout = {
                fill_tile = 'out-of-map',
                railway_tile = 'tutorial-grid',
                railway_corridor_length = 384,
                railway_corridor_height = 8,
                feature_anchor_up = true,
            },
        },
        property_build_type{
            pack = 'utility-science-pack',
            key = 'utility-grid',
            base_width = 128,
            width_per_level = 0.5,
            height = 128,
            height_per_level = 0.2,
            max_width = 1024,
            max_height = 1024,
            initial_price_multiplier = 5,
            fixed_layout = {
                fill_tile = 'out-of-map',
                chunk_grid_tile = 'tutorial-grid',
                chunk_size = 32,
                chunk_inner_size = 30,
                core_tile = 'tutorial-grid',
                core_size = 16,
                feature_anchor_up = true,
            },
        },
        property_build_type{
            pack = 'space-science-pack',
            key = 'sky-cottage',
            expandable = false,
            base_width = 96,
            width_per_level = 0.5,
            height = 96,
            initial_price_multiplier = 3,
            fixed_layout = {
                fill_tile = 'empty-space',
                middle_tile = 'space-platform-foundation',
                middle_size = 16,
                core_tile = 'tutorial-grid',
                core_size = 8,
                feature_anchor_up = true,
            },
            surface_property_overrides = {
                gravity = 0,
                pressure = 0,
                ['magnetic-field'] = 0,
                ['day-night-cycle'] = 0,
            },
        },
        property_build_type{
            pack = 'metallurgic-science-pack',
            key = 'lava-cottage',
            initial_price_multiplier = 6,
            terrain_planet = 'vulcanus',
            fixed_layout = {
                fill_tile = 'volcanic-ash-soil',
            },
            lower_half_out_of_map = true,
            special_areas = upper_band('lava'),
        },
        property_build_type{
            pack = 'electromagnetic-science-pack',
            key = 'oil-cottage',
            initial_price_multiplier = 7,
            terrain_planet = 'fulgora',
            fixed_layout = {
                fill_tile = 'fulgoran-dunes',
            },
            lower_half_out_of_map = true,
            special_areas = upper_band('oil-ocean-deep'),
        },
        property_build_type{
            pack = 'agricultural-science-pack',
            key = 'garden-cottage',
            initial_price_multiplier = 8,
            terrain_planet = 'gleba',
            fixed_layout = {
                fill_tile = 'highland-yellow-rock',
            },
            lower_half_out_of_map = true,
            special_areas = {
                {
                    tile = 'natural-yumako-soil',
                    direction = 'left',
                    finish = 0,
                    top = -2,
                    thickness = 3,
                },
                {
                    tile = 'natural-jellynut-soil',
                    direction = 'right',
                    start = 0,
                    top = -2,
                    thickness = 3,
                },
                {
                    tile = 'wetland-light-green-slime',
                    left = -8,
                    right = 8,
                    top = -2,
                    thickness = 3,
                },
            },
        },
        property_build_type{
            pack = 'cryogenic-science-pack',
            key = 'cryogenic-cottage',
            initial_price_multiplier = 12,
            base_decay_hours = 192,
            decay_hours_per_level = 2,
            base_lifetime_hours = 288,
            lifetime_hours_per_level = 24,
            terrain_planet = 'aquilo',
            fixed_layout = {
                fill_tile = 'dust-lumpy',
            },
            crime_chance_multiplier = 10,
        },
    }

    M.hospice_property_types_by_planet = {
        nauvis = 'shore-cottage',
        vulcanus = 'lava-cottage',
        gleba = 'garden-cottage',
        fulgora = 'oil-cottage',
        aquilo = 'cryogenic-cottage',
    }

    local build_types_by_key = {}
    for _, spec in ipairs(M.property_build_types) do
        build_types_by_key[spec.key] = spec
    end

    local function permanent_prototypes(keys)
        local result = {}
        for _, key in ipairs(keys) do
            local build_type = assert(build_types_by_key[key])
            local width = math.min(
                build_type.max_width,
                math.floor(build_type.base_width / 2) * 2
            )
            local height = math.min(
                build_type.max_height,
                math.floor(build_type.height / 2) * 2
            )
            result[#result + 1] = {
                count = 1,
                width = width,
                height = height,
                decay_hours = build_type.base_decay_hours,
                price = math.min(
                    M.property_price_cap,
                    math.ceil(
                        M.property_build_experience_base
                        * M.property_build_price_per_experience
                        * build_type.initial_price_multiplier
                        * M.permanent_property_initial_price_multiplier
                    )
                ),
                terrain_planet = build_type.terrain_planet,
                fixed_layout = build_type.fixed_layout,
                special_areas = build_type.special_areas,
                lower_half_out_of_map = build_type.lower_half_out_of_map,
                layout_anchor_up = true,
                layout_base_height = build_type.height,
                construction_type = build_type.key,
                construction_level = 0,
                crime_chance_multiplier = build_type.crime_chance_multiplier,
            }
        end
        return result
    end

    M.property_permanent_defaults_by_planet = {
        nauvis = permanent_prototypes{
            'secure-cottage',
            'shore-cottage',
            'rail-estate',
            'utility-grid',
            'sky-cottage',
            'lava-cottage',
            'oil-cottage',
            'garden-cottage',
            'cryogenic-cottage',
        },
        vulcanus = {},
        gleba = {},
        fulgora = {},
        aquilo = {},
    }
end
