return function(M)
    M.market_process_ticks = 5 * M.ticks_per_second
    M.market_boxes_per_pass = 20
    M.market_max_items_per_trade = 1000

    -- Edit this list to choose the items traded by each faction market.
    M.market_items = {
        {name = 'iron-ore', base_price = 100,
            base_stock = 100000, virtual_stock = 900000},
        {name = 'copper-ore', base_price = 100,
            base_stock = 100000, virtual_stock = 900000},
        {name = 'coal', base_price = 100,
            base_stock = 100000, virtual_stock = 900000},
        {name = 'stone', base_price = 100,
            base_stock = 100000, virtual_stock = 900000},
        {name = 'uranium-ore', base_price = 500,
            base_stock = 20000, virtual_stock = 180000},
        {name = 'iron-plate', base_price = 200,
            base_stock = 100000, virtual_stock = 900000},
        {name = 'copper-plate', base_price = 200,
            base_stock = 100000, virtual_stock = 900000},
        {name = 'steel-plate', base_price = 1000,
            base_stock = 20000, virtual_stock = 180000},
    }
end
