return function(M)
    M.market_process_ticks = 5 * M.ticks_per_second
    M.market_boxes_per_pass = 20
    M.market_max_items_per_trade = 1000
    M.market_curve_version = 2
    M.market_initial_stock_value = 1000000
    M.market_empty_price_multiplier = 1000

    -- Edit this list to choose the items traded by each faction market.
    M.market_items = {
        {name = 'iron-ore', base_price = 100},
        {name = 'copper-ore', base_price = 100},
        {name = 'coal', base_price = 100},
        {name = 'stone', base_price = 100},
        {name = 'uranium-ore', base_price = 500},
        {name = 'iron-plate', base_price = 200},
        {name = 'copper-plate', base_price = 200},
        {name = 'steel-plate', base_price = 1000},
    }
end
