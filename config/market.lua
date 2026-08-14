return function(M)
    M.market_curve_version = 5
    M.market_initial_cash = 10000000
    M.market_tax_share = 0.50
    -- A net purchase with this base-price value moves the spot price by the
    -- configured multiplier. Individual items still need only a base price.
    M.market_depth_value = 1000000
    M.market_depth_price_multiplier = 1000
    M.market_sell_fee_rate = 0.01
    M.market_items = {
        {name = 'iron-ore', base_price = 100, group = 'raw'},
        {name = 'copper-ore', base_price = 100, group = 'raw'},
        {name = 'uranium-ore', base_price = 500, group = 'raw'},
        {name = 'coal', base_price = 100, group = 'raw'},
        {name = 'stone', base_price = 100, group = 'raw'},
        {name = 'wood', base_price = 100, group = 'raw'},
        {name = 'ice', base_price = 100, group = 'raw'},
        {name = 'calcite', base_price = 500, group = 'raw'},
        {name = 'tungsten-ore', base_price = 1000, group = 'raw'},
        {name = 'scrap', base_price = 500, group = 'raw'},
        {name = 'holmium-ore', base_price = 1000, group = 'raw'},
        {name = 'yumako-seed', base_price = 1000, group = 'raw'},
        {name = 'jellynut-seed', base_price = 1000, group = 'raw'},
        {name = 'tree-seed', base_price = 1000, group = 'raw'},
        {name = 'spoilage', base_price = 10, group = 'raw'},
        {name = 'lithium', base_price = 1000, group = 'raw'},

        {name = 'iron-plate', base_price = 200, group = 'material'},
        {name = 'copper-plate', base_price = 200, group = 'material'},
        {name = 'steel-plate', base_price = 1000, group = 'material'},
        {name = 'stone-brick', base_price = 200, group = 'material'},
        {name = 'concrete', base_price = 500, group = 'material'},
        {name = 'refined-concrete', base_price = 1000, group = 'material'},
        {name = 'solid-fuel', base_price = 500, group = 'material'},
        {name = 'rocket-fuel', base_price = 5000, group = 'material'},
        {name = 'uranium-fuel-cell', base_price = 5000, group = 'material'},
        {name = 'plastic-bar', base_price = 500, group = 'material'},
        {name = 'sulfur', base_price = 500, group = 'material'},
        {name = 'battery', base_price = 1000, group = 'material'},
        {name = 'explosives', base_price = 1000, group = 'material'},
        {name = 'carbon', base_price = 1000, group = 'material'},
        {name = 'holmium-plate', base_price = 5000, group = 'material'},
        {name = 'lithium-plate', base_price = 5000, group = 'material'},

        {name = 'iron-gear-wheel', base_price = 500, group = 'component'},
        {name = 'copper-cable', base_price = 100, group = 'component'},
        {name = 'electronic-circuit', base_price = 500, group = 'component'},
        {name = 'advanced-circuit', base_price = 2000, group = 'component'},
        {name = 'processing-unit', base_price = 10000, group = 'component'},
        {name = 'engine-unit', base_price = 2000, group = 'component'},
        {name = 'electric-engine-unit', base_price = 5000, group = 'component'},
        {name = 'flying-robot-frame', base_price = 10000, group = 'component'},
        {name = 'low-density-structure', base_price = 10000, group = 'component'},
        {name = 'logistic-robot', base_price = 20000, group = 'component'},
        {name = 'construction-robot', base_price = 20000, group = 'component'},
        {name = 'superconductor', base_price = 10000, group = 'component'},
        {name = 'supercapacitor', base_price = 20000, group = 'component'},
        {name = 'quantum-processor', base_price = 50000, group = 'component'},
        {name = 'fusion-power-cell', base_price = 50000, group = 'component'},

        {name = 'automation-science-pack', base_price = 1000, group = 'science'},
        {name = 'logistic-science-pack', base_price = 2000, group = 'science'},
        {name = 'military-science-pack', base_price = 3000, group = 'science'},
        {name = 'chemical-science-pack', base_price = 5000, group = 'science'},
        {name = 'production-science-pack', base_price = 10000, group = 'science'},
        {name = 'utility-science-pack', base_price = 10000, group = 'science'},
        {name = 'space-science-pack', base_price = 20000, group = 'science'},
        {name = 'metallurgic-science-pack', base_price = 20000, group = 'science'},
        {name = 'agricultural-science-pack', base_price = 20000, group = 'science'},
        {name = 'electromagnetic-science-pack', base_price = 20000, group = 'science'},
        {name = 'cryogenic-science-pack', base_price = 50000, group = 'science'},
        {name = 'promethium-science-pack', base_price = 100000, group = 'science'},
    }
end
