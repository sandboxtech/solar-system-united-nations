return function(M)
    M.faction_initial_technologies = {
        -- Generic trigger technologies.
        'steam-power',
        'electronics',
        'automation-science-pack',
        'steel-axe',
        'oil-processing',
        -- 'uranium-processing',
        'space-platform',
        'space-science-pack',
    }
    M.faction_initial_technologies_by_planet = {
        -- Nauvis is the default location and has no planet-discovery-nauvis
        -- technology prototype.
        nauvis = {},
        vulcanus = {
            'planet-discovery-vulcanus',
            'calcite-processing',
            'tungsten-carbide',
            'big-mining-drill',
            'foundry',
            'tungsten-steel',
            'metallurgic-science-pack',
        },
        gleba = {
            'planet-discovery-gleba',
            'agriculture',
            'heating-tower',
            'yumako',
            'biochamber',
            'jellynut',
            'bioflux',
            'artificial-soil',
            'bacteria-cultivation',
            'bioflux-processing',
            'agricultural-science-pack',
            -- 'biter-egg-handling',
        },
        fulgora = {
            'planet-discovery-fulgora',
            'recycling',
            'holmium-processing',
            'electromagnetic-plant',
            'electromagnetic-science-pack',
        },
        aquilo = {
            'planet-discovery-aquilo',
            'heating-tower',
            'lithium-processing',
            'cryogenic-plant',
            'cryogenic-science-pack',
        },
    }
    M.faction_initial_technologies_recursive = {
        'landfill',
        'solar-energy',
        'electric-engine',
        'electric-energy-accumulators',
    }
    M.faction_initial_technologies_recursive_by_planet = {
        nauvis = {},
        vulcanus = {},
        gleba = {},
        fulgora = {},
        aquilo = {
            'cryogenic-science-pack',
        },
    }
    M.faction_initial_recipes = {
        'ice-melting',
        'loader',
        'fast-loader',
        'express-loader',
        'turbo-loader',
    }
    M.tech_leak_immune_technologies = {
        'logistic-robotics',
        'space-platform-thruster',
        'planet-discovery-vulcanus',
        'planet-discovery-gleba',
        'planet-discovery-fulgora',
        'planet-discovery-aquilo',
    }

    M.tech_leak_interval_hours = 1
    M.tech_leak_coefficient_max_percent = 0.25
    M.tech_leak_max_affected = 5
    M.tech_leak_unlock_technology = M.faction_diplomacy_technology
    M.tech_leak_chance_multiplier_by_planet = {
        nauvis = 1,
        vulcanus = 1,
        gleba = 1,
        fulgora = 1,
        aquilo = 0.001,
    }

    M.science_pack_experience = {
        ['automation-science-pack'] = 1,
        ['logistic-science-pack'] = 1,
        ['military-science-pack'] = 1,
        ['chemical-science-pack'] = 1,
        ['production-science-pack'] = 1,
        ['utility-science-pack'] = 1,
        ['space-science-pack'] = 1,
        ['metallurgic-science-pack'] = 1,
        ['agricultural-science-pack'] = 1,
        ['electromagnetic-science-pack'] = 1,
        ['cryogenic-science-pack'] = 1,
        ['promethium-science-pack'] = 1,
    }
    M.science_pack_order = {
        'automation-science-pack',
        'logistic-science-pack',
        'military-science-pack',
        'chemical-science-pack',
        'production-science-pack',
        'utility-science-pack',
        'space-science-pack',
        'metallurgic-science-pack',
        'agricultural-science-pack',
        'electromagnetic-science-pack',
        'cryogenic-science-pack',
        'promethium-science-pack',
    }
end
