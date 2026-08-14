return function(M)
    M.market_curve_version = 10
    M.market_base_price_multiplier = 1
    M.market_initial_cash = 100000000
    M.property_tax_market_share = 0.60
    -- All goods and the coin reserve grow with the same linear multiplier:
    -- S(t) = 1 + elapsed_hours / market_depth_growth_hours.
    M.market_coin_depth_start = 10000000
    M.market_item_depth_start = 100000
    M.market_depth_growth_hours = 10
    M.market_items = {
        {name = 'iron-ore', base_price = 2, group = 'raw'},
        {name = 'copper-ore', base_price = 2, group = 'raw'},
        {name = 'uranium-ore', base_price = 2, group = 'raw'},
        {name = 'coal', base_price = 2, group = 'raw'},
        {name = 'stone', base_price = 2, group = 'raw'},
        {name = 'wood', base_price = 2, group = 'raw'},
        {name = 'ice', base_price = 1, group = 'raw'},
        {name = 'calcite', base_price = 2, group = 'raw'},
        {name = 'tungsten-ore', base_price = 10, group = 'raw'},
        {name = 'scrap', base_price = 2, group = 'raw'},
        {name = 'holmium-ore', base_price = 2, group = 'raw'},
        {name = 'yumako-seed', base_price = 2, group = 'raw'},
        {name = 'jellynut-seed', base_price = 2, group = 'raw'},
        {name = 'tree-seed', base_price = 2, group = 'raw'},
        {name = 'spoilage', base_price = 1, group = 'raw'},
        {name = 'lithium', base_price = 2, group = 'raw'},


        {name = 'iron-plate', base_price = 2, group = 'material'},
        {name = 'copper-plate', base_price = 2, group = 'material'},
        {name = 'steel-plate', base_price = 10, group = 'material'},
        {name = 'stone-brick', base_price = 4, group = 'material'},
        {name = 'concrete', base_price = 2, group = 'material'},
        {name = 'refined-concrete', base_price = 6, group = 'material'},

        {name = 'solid-fuel', base_price = 2, group = 'material'},
        {name = 'rocket-fuel', base_price = 20, group = 'material'},
        {name = 'uranium-fuel-cell', base_price = 40, group = 'material'},
        {name = 'fusion-power-cell', base_price = 12, group = 'material'},

        {name = 'plastic-bar', base_price = 3, group = 'material'},
        {name = 'sulfur', base_price = 2, group = 'material'},
        {name = 'battery', base_price = 5, group = 'material'},
        {name = 'explosives', base_price = 2, group = 'material'},
        {name = 'carbon', base_price = 5, group = 'material'},
        {name = 'holmium-plate', base_price = 2, group = 'material'},
        {name = 'lithium-plate', base_price = 2, group = 'material'},
        {name = 'tungsten-carbide', base_price = 20, group = 'material'},
        {name = 'tungsten-plate', base_price = 40, group = 'material'},
        {name = 'carbon-fiber', base_price = 10, group = 'material'},

        {name = 'iron-gear-wheel', base_price = 4, group = 'component'},
        {name = 'copper-cable', base_price = 1, group = 'component'},
        {name = 'electronic-circuit', base_price = 5, group = 'component'},
        {name = 'advanced-circuit', base_price = 20, group = 'component'},
        {name = 'processing-unit', base_price = 140, group = 'component'},

        {name = 'engine-unit', base_price = 20, group = 'component'},
        {name = 'electric-engine-unit', base_price = 30, group = 'component'},
        {name = 'flying-robot-frame', base_price = 70, group = 'component'},
        {name = 'low-density-structure', base_price = 75, group = 'component'},
        {name = 'logistic-robot', base_price = 90, group = 'component'},
        {name = 'construction-robot', base_price = 75, group = 'component'},

        {name = 'superconductor', base_price = 3, group = 'component'},
        {name = 'supercapacitor', base_price = 40, group = 'component'},
        {name = 'quantum-processor', base_price = 180, group = 'component'},

        {name = 'automation-science-pack', base_price = 6, group = 'science'},
        {name = 'logistic-science-pack', base_price = 15, group = 'science'},
        {name = 'military-science-pack', base_price = 45, group = 'science'},
        {name = 'chemical-science-pack', base_price = 40, group = 'science'},
        {name = 'production-science-pack', base_price = 100, group = 'science'},
        {name = 'utility-science-pack', base_price = 100, group = 'science'},
        {name = 'space-science-pack', base_price = 10, group = 'science'},
        {name = 'metallurgic-science-pack', base_price = 100, group = 'science'},
        {name = 'agricultural-science-pack', base_price = 10, group = 'science'},
        {name = 'electromagnetic-science-pack', base_price = 80, group = 'science'},
        {name = 'cryogenic-science-pack', base_price = 20, group = 'science'},
        {name = 'promethium-science-pack', base_price = 30, group = 'science'},
    }
end
