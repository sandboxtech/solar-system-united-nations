return function(M)
    local function property_build_type(spec)
        spec.base_width = spec.base_width or 32
        spec.width_per_level = spec.width_per_level or 2
        spec.height = spec.height or 32
        spec.height_per_level = spec.height_per_level or 1
        spec.max_width = spec.max_width or 256
        spec.max_height = spec.max_height or 256
        if spec.exact_dimensions == nil then spec.exact_dimensions = true end
        spec.initial_price_multiplier = spec.initial_price_multiplier or 1
        spec.base_decay_hours = spec.base_decay_hours or 10
        spec.decay_hours_per_level = spec.decay_hours_per_level or 1
        spec.base_lifetime_hours = spec.base_lifetime_hours or 100
        spec.lifetime_hours_per_level = spec.lifetime_hours_per_level or 1
        if spec.expandable == nil then spec.expandable = true end
        return spec
    end

    local function side_bands(tile)
        return {
            {
                tile = tile,
                direction = 'right',
                start = 2,
                top = 3,
                thickness = 2,
            },
            {
                tile = tile,
                direction = 'left',
                finish = 0,
                top = -3,
                thickness = 2,
            },
        }
    end

    M.property_build_types = {
        property_build_type{
            pack = 'automation-science-pack',
            key = 'shelter',
            base_decay_hours = 2,
            decay_hours_per_level = 0.1,
            base_lifetime_hours = 10,
            lifetime_hours_per_level = 1,
        },
        property_build_type{
            pack = 'logistic-science-pack',
            key = 'cottage',
            initial_price_multiplier = 2,
            base_decay_hours = 6,
            decay_hours_per_level = 0.2,
            base_lifetime_hours = 30,
            lifetime_hours_per_level = 3,
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
            special_areas = side_bands('water'),
        },
        property_build_type{
            pack = 'production-science-pack',
            key = 'rail-estate',
            base_width = 512,
            width_per_level = 2,
            max_width = 1024,
            height = 64,
            height_per_level = 1,
            max_height = 320,
            exact_dimensions = true,
            initial_price_multiplier = 4,
            fixed_layout = {
                fill_tile = 'out-of-map',
                railway_tile = 'tutorial-grid',
                railway_corridor_length = 384,
                railway_corridor_height = 8,
            },
        },
        property_build_type{
            pack = 'utility-science-pack',
            key = 'utility-grid',
            base_width = 128,
            width_per_level = 2,
            height = 128,
            height_per_level = 1,
            max_width = 1024,
            max_height = 1024,
            exact_dimensions = true,
            initial_price_multiplier = 5,
            fixed_layout = {
                fill_tile = 'out-of-map',
                chunk_grid_tile = 'tutorial-grid',
                chunk_size = 32,
                chunk_inner_size = 30,
                core_tile = 'tutorial-grid',
                core_size = 16,
            },
        },
        property_build_type{
            pack = 'space-science-pack',
            key = 'sky-cottage',
            expandable = false,
            base_width = 96,
            width_per_level = 2,
            height = 96,
            initial_price_multiplier = 3,
            fixed_layout = {
                fill_tile = 'empty-space',
                middle_tile = 'space-platform-foundation',
                middle_size = 16,
                core_tile = 'tutorial-grid',
                core_size = 8,
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
            special_areas = side_bands('lava'),
        },
        property_build_type{
            pack = 'electromagnetic-science-pack',
            key = 'oil-cottage',
            initial_price_multiplier = 7,
            terrain_planet = 'fulgora',
            special_areas = side_bands('oil-ocean-deep'),
        },
        property_build_type{
            pack = 'agricultural-science-pack',
            key = 'garden-cottage',
            initial_price_multiplier = 8,
            terrain_planet = 'gleba',
            special_areas = {
                {
                    tile = 'natural-yumako-soil',
                    direction = 'right',
                    start = 2,
                    top = 3,
                    thickness = 2,
                },
                {
                    tile = 'natural-jellynut-soil',
                    direction = 'left',
                    finish = 0,
                    top = -3,
                    thickness = 2,
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

    local function permanent_rentals(count)
        return {
            {
                count = count,
                width = M.rental_property_default_width,
                height = M.rental_property_default_height,
                decay_hours = M.rental_property_decay_hours,
                fixed_layout = M.rental_property_fixed_layout,
                entity_layout_version = M.property_entity_layout_version,
            },
        }
    end

    M.property_permanent_defaults_by_planet = {
        nauvis = permanent_rentals(10),
        vulcanus = permanent_rentals(3),
        gleba = permanent_rentals(3),
        fulgora = permanent_rentals(3),
        aquilo = permanent_rentals(3),
    }
end
