local config = require('config')
local economy = require('scripts.economy')
local factions = require('scripts.factions')
local settings = require('scripts.settings')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

local M = {}

local MAX_SAFE_INTEGER = 9007199254740991
local ROUNDING_EPSILON = 0.000000001
local item_specs = {}
local base_price_multiplier = config.market_base_price_multiplier or 1

assert(type(base_price_multiplier) == 'number' and base_price_multiplier > 0,
    'market_base_price_multiplier must be greater than zero')

for _, spec in ipairs(config.market_items or {}) do
    assert(type(spec.name) == 'string' and spec.name ~= '',
        'market item name must not be empty')
    assert(type(spec.base_price) == 'number' and spec.base_price > 0,
        'market base_price must be greater than zero: ' .. spec.name)
    assert(not item_specs[spec.name], 'duplicate market item: ' .. spec.name)
    item_specs[spec.name] = spec
end
assert(config.market_initial_cash > 0
        and config.market_initial_cash == math.floor(config.market_initial_cash),
    'market_initial_cash must be a positive integer')
assert(config.market_coin_depth_start > 0,
    'market_coin_depth_start must be greater than zero')
assert(config.market_item_depth_start > 0,
    'market_item_depth_start must be greater than zero')
assert(config.market_depth_growth_hours > 0,
    'market_depth_growth_hours must be greater than zero')
assert(config.property_tax_market_share >= 0
        and config.property_tax_market_share <= 1,
    'property_tax_market_share must be between zero and one')

local function valid_number(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_nonnegative_integer(value)
    return valid_number(value) and value >= 0
        and value <= MAX_SAFE_INTEGER
        and value == math.floor(value)
end

local function valid_count(value)
    return valid_nonnegative_integer(value) and value > 0
end

local function valid_remainder(value, minimum, maximum)
    return valid_number(value) and value >= minimum and value <= maximum
end

local function initial_stock()
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        result[spec.name] = 0
    end
    return result
end

local function initial_virtual_stock(item_depth)
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        result[spec.name] = item_depth
            / (spec.base_price * base_price_multiplier)
    end
    return result
end

local function configured_price_multiplier()
    return settings.get('market_price_percent') / 100
end

local function configured_item_depth_multiplier()
    return settings.get('market_item_depth_multiplier')
end

local function configured_coin_depth_multiplier()
    return settings.get('market_coin_depth_multiplier')
end

local function depth_multiplier_now()
    local started = storage.market_depth_started_tick or game.tick
    local elapsed = math.max(0, game.tick - started)
    local quantum = config.ticks_per_minute
    elapsed = math.floor(elapsed / quantum) * quantum
    return 1 + elapsed
        / (config.market_depth_growth_hours * config.ticks_per_hour)
end

local function initial_market()
    local depth_multiplier = depth_multiplier_now()
    local item_depth_multiplier = configured_item_depth_multiplier()
    local coin_depth_multiplier = configured_coin_depth_multiplier()
    local price_multiplier = configured_price_multiplier()
    local item_depth = config.market_item_depth_start
        * item_depth_multiplier * depth_multiplier
    local coin_depth = config.market_coin_depth_start
        * coin_depth_multiplier * depth_multiplier
    return {
        cash = config.market_initial_cash,
        liquidity = coin_depth * price_multiplier,
        item_depth = item_depth,
        coin_depth = coin_depth,
        depth_multiplier = depth_multiplier,
        price_multiplier = price_multiplier,
        item_depth_multiplier = item_depth_multiplier,
        coin_depth_multiplier = coin_depth_multiplier,
        stock = initial_stock(),
        virtual_stock = initial_virtual_stock(item_depth),
        buy_rounding_remainder = 0,
        sell_rounding_remainder = 0,
        property_tax_rounding_remainder = 0,
    }
end

local function ensure_curve()
    if storage.market_curve_version == config.market_curve_version then
        if not valid_nonnegative_integer(storage.market_depth_started_tick)
                or storage.market_depth_started_tick > game.tick then
            storage.market_depth_started_tick = game.tick
        end
        return
    end
    local previous_version = storage.market_curve_version
    storage.market_depth_started_tick = game.tick
    if previous_version == 9 and type(storage.local_markets) == 'table' then
        -- Keep national cash and actual stock while lowering every current
        -- unit price by the same factor as the new initial prices.
        for _, market in pairs(storage.local_markets) do
            if type(market) == 'table'
                    and type(market.stock) == 'table'
                    and type(market.virtual_stock) == 'table' then
                for _, spec in ipairs(config.market_items or {}) do
                    local stock = valid_nonnegative_integer(
                        market.stock[spec.name]
                    ) and market.stock[spec.name] or 0
                    local virtual = market.virtual_stock[spec.name]
                    if valid_number(virtual) and virtual > 0 then
                        market.virtual_stock[spec.name]
                            = (virtual + stock) / base_price_multiplier - stock
                    end
                end
            end
        end
    elseif previous_version == 8 and type(storage.local_markets) == 'table' then
        -- Version 8 used V=1,000,000 and tied the coin depth to its
        -- 20,000,000 starting cash. Preserve stock, cash and current prices.
        local old_item_depth = 1000000
        local old_coin_depth = 20000000
        for _, market in pairs(storage.local_markets) do
            if type(market) == 'table' then
                local old_liquidity = valid_number(market.liquidity)
                    and market.liquidity > 0 and market.liquidity
                    or old_coin_depth
                market.item_depth = config.market_item_depth_start
                market.coin_depth = config.market_coin_depth_start
                market.depth_multiplier = 1
                market.liquidity = old_liquidity
                    * config.market_coin_depth_start / old_coin_depth
                if type(market.stock) ~= 'table' then
                    market.stock = initial_stock()
                end
                market.virtual_stock = {}
                for _, spec in ipairs(config.market_items or {}) do
                    local stock = valid_nonnegative_integer(
                        market.stock[spec.name]
                    ) and market.stock[spec.name] or 0
                    market.stock[spec.name] = stock
                    local old_effective = old_item_depth / spec.base_price
                        + stock
                    market.virtual_stock[spec.name]
                        = config.market_item_depth_start / old_item_depth
                            * old_effective / base_price_multiplier - stock
                end
            end
        end
    else
        storage.local_markets = {}
    end
    storage.market_curve_version = config.market_curve_version
    if type(storage.market_revisions) ~= 'table' then
        storage.market_revisions = {}
    end
end

local function normalize_market(market)
    if not valid_nonnegative_integer(market.cash)
            or market.cash > MAX_SAFE_INTEGER then
        market.cash = config.market_initial_cash
    end
    if not valid_number(market.liquidity) or market.liquidity <= 0
            or market.liquidity > MAX_SAFE_INTEGER then
        market.liquidity = config.market_coin_depth_start
    end
    if not valid_number(market.depth_multiplier)
            or market.depth_multiplier <= 0 then
        market.depth_multiplier = 1
    end
    if not valid_number(market.price_multiplier)
            or market.price_multiplier <= 0 then
        market.price_multiplier = 1
    end
    if not valid_number(market.item_depth_multiplier)
            or market.item_depth_multiplier <= 0 then
        market.item_depth_multiplier = 1
    end
    if not valid_number(market.coin_depth_multiplier)
            or market.coin_depth_multiplier <= 0 then
        market.coin_depth_multiplier = 1
    end
    if not valid_number(market.item_depth) or market.item_depth <= 0
            or market.item_depth > MAX_SAFE_INTEGER then
        market.item_depth = config.market_item_depth_start
            * market.item_depth_multiplier * market.depth_multiplier
    end
    if not valid_number(market.coin_depth) or market.coin_depth <= 0
            or market.coin_depth > MAX_SAFE_INTEGER then
        market.coin_depth = config.market_coin_depth_start
            * market.coin_depth_multiplier * market.depth_multiplier
    end
    if type(market.stock) ~= 'table' then market.stock = initial_stock() end
    if type(market.virtual_stock) ~= 'table' then
        market.virtual_stock = initial_virtual_stock(market.item_depth)
    end
    for _, spec in ipairs(config.market_items or {}) do
        if not valid_nonnegative_integer(market.stock[spec.name]) then
            market.stock[spec.name] = 0
        end
        local virtual = market.virtual_stock[spec.name]
        if not valid_number(virtual) or virtual <= 0
                or virtual > MAX_SAFE_INTEGER then
            market.virtual_stock[spec.name]
                = market.item_depth
                    / (spec.base_price * base_price_multiplier)
        end
    end
    if not valid_remainder(market.buy_rounding_remainder, -1, 0) then
        market.buy_rounding_remainder = 0
    end
    if not valid_remainder(market.sell_rounding_remainder, 0, 1) then
        market.sell_rounding_remainder = 0
    end
    if not valid_remainder(market.property_tax_rounding_remainder, 0, 1) then
        market.property_tax_rounding_remainder = 0
    end
    return market
end

local function apply_depth_growth(market, force_name)
    local target = depth_multiplier_now()
    if target <= market.depth_multiplier then return false end
    local factor = target / market.depth_multiplier
    local next_liquidity = market.liquidity * factor
    local next_item_depth = config.market_item_depth_start
        * market.item_depth_multiplier * target
    local next_coin_depth = config.market_coin_depth_start
        * market.coin_depth_multiplier * target
    if next_liquidity > MAX_SAFE_INTEGER
            or next_item_depth > MAX_SAFE_INTEGER
            or next_coin_depth > MAX_SAFE_INTEGER then
        return false
    end
    local next_virtual_stock = {}
    for _, spec in ipairs(config.market_items or {}) do
        local stock = market.stock[spec.name]
        local virtual = factor
            * (market.virtual_stock[spec.name] + stock) - stock
        if not valid_number(virtual) or virtual <= 0
                or virtual > MAX_SAFE_INTEGER then
            return false
        end
        next_virtual_stock[spec.name] = virtual
    end
    market.depth_multiplier = target
    market.item_depth = next_item_depth
    market.coin_depth = next_coin_depth
    market.liquidity = next_liquidity
    market.virtual_stock = next_virtual_stock
    storage.market_revisions[force_name]
        = (storage.market_revisions[force_name] or 0) + 1
    return true
end

local function market_for_force(force_name)
    ensure_curve()
    local market = storage.local_markets[force_name]
    if type(market) ~= 'table' then
        market = initial_market()
        storage.local_markets[force_name] = market
    end
    normalize_market(market)
    apply_depth_growth(market, force_name)
    return market
end

local function market_for_player(player)
    local planet_name = player and factions.of_player(player)
    local force = planet_name and factions.of_planet(planet_name)
    if not (force and player.force == force) then return nil, 'no-faction' end
    local physical_surface = player.physical_surface
    if not (physical_surface and physical_surface.valid)
            or physical_surface.platform
            or surfaces.context_planet(physical_surface) ~= planet_name then
        return nil, 'invalid-location'
    end
    return market_for_force(force.name), force.name
end

local function market_for_player_index(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid and player.connected) then
        return nil, 'player-offline'
    end
    return market_for_player(player)
end

local function spot_price(market, spec, stock)
    return market.item_depth
        / (market.virtual_stock[spec.name] + stock)
        * market.liquidity / market.coin_depth
end

-- Integral of the inventory-only price curve over [lower_stock, upper_stock].
local function inventory_curve_value(market, spec, lower_stock, upper_stock)
    if lower_stock < 0 or upper_stock <= lower_stock then return nil end
    local virtual = market.virtual_stock[spec.name]
    local raw = market.item_depth * math.log(
        (virtual + upper_stock) / (virtual + lower_stock)
    )
    if not valid_number(raw) or raw <= 0 or raw > MAX_SAFE_INTEGER then
        return nil
    end
    return raw
end

local function ceil_with_remainder(raw, remainder)
    local combined = raw + (remainder or 0)
    local amount = math.ceil(combined - ROUNDING_EPSILON)
    local next_remainder = combined - amount
    if math.abs(next_remainder) < ROUNDING_EPSILON then next_remainder = 0 end
    return amount, next_remainder
end

local function floor_with_remainder(raw, remainder)
    local combined = raw + (remainder or 0)
    local amount = math.floor(combined + ROUNDING_EPSILON)
    local next_remainder = combined - amount
    if math.abs(next_remainder) < ROUNDING_EPSILON then next_remainder = 0 end
    return amount, next_remainder
end

local function property_tax_market_share()
    return settings.get('property_tax_market_share_percent') / 100
end

local function buy_settlement(market, spec, count)
    local stock = market.stock[spec.name]
    if count > stock then return nil, 'out-of-stock' end
    local curve_value = inventory_curve_value(
        market, spec, stock - count, stock
    )
    if not curve_value then return nil, 'no-value' end
    local multiplier = math.exp(curve_value / market.coin_depth)
    local next_liquidity = market.liquidity * multiplier
    local raw_cost = next_liquidity - market.liquidity
    if not valid_number(next_liquidity) or not valid_number(raw_cost)
            or next_liquidity > MAX_SAFE_INTEGER
            or raw_cost > MAX_SAFE_INTEGER then
        return nil, 'credit-limit'
    end
    local cost, rounding_remainder = ceil_with_remainder(
        raw_cost,
        market.buy_rounding_remainder
    )
    if cost <= 0 then return nil, 'no-value' end
    if market.cash + cost > MAX_SAFE_INTEGER then
        return nil, 'credit-limit'
    end
    return {
        count = count,
        cost = cost,
        next_liquidity = next_liquidity,
        rounding_remainder = rounding_remainder,
    }
end

local function sell_settlement(market, spec, count)
    local stock = market.stock[spec.name]
    local curve_value = inventory_curve_value(
        market, spec, stock, stock + count
    )
    if not curve_value then return nil, 'no-value' end
    local next_liquidity = market.liquidity
        * math.exp(-curve_value / market.coin_depth)
    if not valid_number(next_liquidity) or next_liquidity <= 0 then
        return nil, 'no-value'
    end
    local raw_revenue = market.liquidity - next_liquidity
    if not valid_number(raw_revenue) or raw_revenue <= 0
            or raw_revenue > MAX_SAFE_INTEGER then
        return nil, 'no-value'
    end
    local revenue, rounding_remainder = floor_with_remainder(
        raw_revenue,
        market.sell_rounding_remainder
    )
    if revenue <= 0 then return nil, 'no-value' end
    if revenue > market.cash then
        return nil, 'insufficient-market-credit'
    end
    return {
        count = count,
        revenue = revenue,
        next_liquidity = next_liquidity,
        rounding_remainder = rounding_remainder,
    }
end

local function apply_buy(market, item_name, settlement)
    market.stock[item_name] = market.stock[item_name] - settlement.count
    market.cash = market.cash + settlement.cost
    market.liquidity = settlement.next_liquidity
    market.buy_rounding_remainder = settlement.rounding_remainder
end

local function apply_sell(market, item_name, settlement)
    market.stock[item_name] = market.stock[item_name] + settlement.count
    market.cash = market.cash - settlement.revenue
    market.liquidity = settlement.next_liquidity
    market.sell_rounding_remainder = settlement.rounding_remainder
end

local function copy_market(market)
    local result = {}
    for key, value in pairs(market) do
        if key ~= 'stock' and key ~= 'virtual_stock' then result[key] = value end
    end
    result.stock = {}
    for name, count in pairs(market.stock) do result.stock[name] = count end
    result.virtual_stock = {}
    for name, count in pairs(market.virtual_stock) do
        result.virtual_stock[name] = count
    end
    return result
end

local function reconfigured_market(market)
    local draft = copy_market(market)
    local price_multiplier = configured_price_multiplier()
    local item_depth_multiplier = configured_item_depth_multiplier()
    local coin_depth_multiplier = configured_coin_depth_multiplier()
    local item_factor = item_depth_multiplier / market.item_depth_multiplier
    local coin_factor = coin_depth_multiplier / market.coin_depth_multiplier
    local price_factor = price_multiplier / market.price_multiplier

    draft.item_depth = market.item_depth * item_factor
    draft.coin_depth = market.coin_depth * coin_factor
    draft.liquidity = market.liquidity * coin_factor * price_factor
    if not valid_number(draft.item_depth) or draft.item_depth <= 0
            or draft.item_depth > MAX_SAFE_INTEGER
            or not valid_number(draft.coin_depth) or draft.coin_depth <= 0
            or draft.coin_depth > MAX_SAFE_INTEGER
            or not valid_number(draft.liquidity) or draft.liquidity <= 0
            or draft.liquidity > MAX_SAFE_INTEGER then
        return nil
    end

    for _, spec in ipairs(config.market_items or {}) do
        local stock = market.stock[spec.name]
        local effective_stock = item_factor
            * (market.virtual_stock[spec.name] + stock)
        local virtual = effective_stock - stock
        -- A very shallow setting can put the curve singularity inside the
        -- actual inventory. Keep a positive virtual reserve in that case.
        if virtual <= ROUNDING_EPSILON then virtual = ROUNDING_EPSILON end
        if not valid_number(virtual) or virtual > MAX_SAFE_INTEGER then
            return nil
        end
        draft.virtual_stock[spec.name] = virtual
    end
    draft.price_multiplier = price_multiplier
    draft.item_depth_multiplier = item_depth_multiplier
    draft.coin_depth_multiplier = coin_depth_multiplier
    return draft
end

local function bump_revision(force_name)
    storage.market_revisions[force_name]
        = (storage.market_revisions[force_name] or 0) + 1
end

local function main_inventory(player)
    local inventory = player and player.get_main_inventory()
    return inventory and inventory.valid and inventory or nil
end

function M.ensure()
    state.ensure()
    ensure_curve()
    for _, entry in ipairs(factions.all()) do
        market_for_force(entry.force.name)
    end
end

function M.apply_admin_settings()
    state.ensure()
    ensure_curve()
    local replacements = {}
    for force_name, market in pairs(storage.local_markets) do
        if type(market) == 'table' then
            normalize_market(market)
            local draft = reconfigured_market(market)
            if not draft then return false end
            replacements[force_name] = draft
        end
    end
    for force_name, market in pairs(replacements) do
        storage.local_markets[force_name] = market
        bump_revision(force_name)
    end
    return true
end

function M.revision(player)
    local _, force_name = market_for_player(player)
    return force_name and (storage.market_revisions[force_name] or 0) or 0
end

function M.cash(player)
    local market, err = market_for_player(player)
    return market and market.cash or nil, err
end

function M.list(player)
    local market, force_name = market_for_player(player)
    if not market then return nil, force_name end
    local inventory = main_inventory(player)
    if not inventory then return nil, 'no-inventory' end
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        local stock = market.stock[spec.name]
        result[#result + 1] = {
            name = spec.name,
            group = spec.group,
            stock = stock,
            price = spot_price(market, spec, stock),
            carried = inventory.get_item_count{
                name = spec.name,
                quality = 'normal',
            },
        }
    end
    return result, force_name
end

function M.is_tradable(item_name)
    return item_specs[item_name] ~= nil
end

function M.buy_quote(player, item_name, count)
    if not valid_count(count) then return nil, 'invalid-count' end
    local spec = item_specs[item_name]
    if not spec then return nil, 'invalid-item' end
    local market, err = market_for_player(player)
    if not market then return nil, err end
    local settlement, quote_err = buy_settlement(market, spec, count)
    return settlement and settlement.cost or nil, quote_err
end

function M.buy_into_inventory(player_index, item_name, count, inventory)
    if not valid_count(count) or not (inventory and inventory.valid) then
        return false, 'invalid-count'
    end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player_index(player_index)
    if not market then return false, force_name end
    local insertable = inventory.get_insertable_count{
        name = item_name, quality = 'normal',
    }
    count = math.min(count, insertable, market.stock[item_name])
    if count <= 0 then
        return false, market.stock[item_name] <= 0
            and 'out-of-stock' or 'inventory-full'
    end
    local balance = economy.get_balance(player_index)
    local settlement, err = buy_settlement(market, spec, count)
    while count > 0 and (not settlement or settlement.cost > balance) do
        if err == 'out-of-stock' then return false, err end
        count = math.floor(count / 2)
        if count > 0 then
            settlement, err = buy_settlement(market, spec, count)
        else
            settlement = nil
        end
    end
    if count <= 0 or not settlement then
        return false, err or 'insufficient-credit'
    end
    local inserted = inventory.insert{
        name = item_name, count = count, quality = 'normal',
    }
    if inserted ~= count then
        if inserted > 0 then
            inventory.remove{name = item_name, count = inserted, quality = 'normal'}
        end
        return false, 'inventory-full'
    end
    if not economy.change(player_index, -settlement.cost, 'market-auto-buy') then
        inventory.remove{name = item_name, count = count, quality = 'normal'}
        return false, 'insufficient-credit'
    end
    apply_buy(market, item_name, settlement)
    bump_revision(force_name)
    return true, count, settlement.cost
end

function M.sell_from_inventory(player_index, item_name, inventory, requested)
    if not (inventory and inventory.valid) then return false, 'no-inventory' end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player_index(player_index)
    if not market then return false, force_name end
    local carried = inventory.get_item_count{
        name = item_name, quality = 'normal',
    }
    local count = requested == nil and carried
        or valid_count(requested) and math.min(carried, requested) or 0
    if count <= 0 then return false, 'nothing-to-sell' end
    local settlement, err = sell_settlement(market, spec, count)
    while count > 0 and not settlement
            and err == 'insufficient-market-credit' do
        count = math.floor(count / 2)
        if count > 0 then
            settlement, err = sell_settlement(market, spec, count)
        end
    end
    if not settlement then return false, err end
    local removed = inventory.remove{
        name = item_name, count = count, quality = 'normal',
    }
    if removed ~= count then
        if removed > 0 then
            inventory.insert{name = item_name, count = removed, quality = 'normal'}
        end
        return false, 'inventory-changed'
    end
    if not economy.change(player_index, settlement.revenue, 'market-auto-sell') then
        inventory.insert{name = item_name, count = count, quality = 'normal'}
        return false, 'credit-limit'
    end
    apply_sell(market, item_name, settlement)
    bump_revision(force_name)
    return true, count, settlement.revenue
end

function M.buy(player, item_name, requested)
    if not valid_count(requested) then return false, 'invalid-count' end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end
    local settlement, err = buy_settlement(market, spec, requested)
    if not settlement then return false, err end
    if inventory.get_insertable_count{
            name = item_name, quality = 'normal'} < requested then
        return false, 'inventory-full'
    end
    if economy.get_balance(player.index) < settlement.cost then
        return false, 'insufficient-credit'
    end
    local inserted = inventory.insert{
        name = item_name, count = requested, quality = 'normal',
    }
    if inserted ~= requested then
        if inserted > 0 then
            inventory.remove{name = item_name, count = inserted, quality = 'normal'}
        end
        return false, 'inventory-full'
    end
    if not economy.change(player.index, -settlement.cost, 'market-buy') then
        inventory.remove{name = item_name, count = requested, quality = 'normal'}
        return false, 'insufficient-credit'
    end
    apply_buy(market, item_name, settlement)
    bump_revision(force_name)
    return true, requested, settlement.cost
end

function M.sell(player, item_name)
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end
    local count = inventory.get_item_count{
        name = item_name, quality = 'normal',
    }
    if count <= 0 then return false, 'nothing-to-sell' end
    local settlement, err = sell_settlement(market, spec, count)
    if not settlement then return false, err end
    local removed = inventory.remove{
        name = item_name, count = count, quality = 'normal',
    }
    if removed ~= count then
        if removed > 0 then
            inventory.insert{name = item_name, count = removed, quality = 'normal'}
        end
        return false, 'inventory-changed'
    end
    if not economy.change(player.index, settlement.revenue, 'market-sell') then
        inventory.insert{name = item_name, count = count, quality = 'normal'}
        return false, 'credit-limit'
    end
    apply_sell(market, item_name, settlement)
    bump_revision(force_name)
    return true, count, settlement.revenue
end

local function prepare_sell_all(player)
    local market, force_name = market_for_player(player)
    if not market then return nil, force_name end
    local inventory = main_inventory(player)
    if not inventory then return nil, 'no-inventory' end
    local draft = copy_market(market)
    local settlements = {}
    local total_count = 0
    local total_revenue = 0
    for _, spec in ipairs(config.market_items or {}) do
        local count = inventory.get_item_count{
            name = spec.name, quality = 'normal',
        }
        if count > 0 then
            local settlement, err = sell_settlement(draft, spec, count)
            if settlement then
                apply_sell(draft, spec.name, settlement)
                settlements[#settlements + 1] = {
                    name = spec.name,
                    count = count,
                }
                total_count = total_count + count
                total_revenue = total_revenue + settlement.revenue
            elseif err == 'insufficient-market-credit' then
                return nil, err
            end
        end
    end
    if total_count <= 0 then return nil, 'nothing-to-sell' end
    return {
        draft = draft,
        force_name = force_name,
        inventory = inventory,
        settlements = settlements,
        total_count = total_count,
        total_revenue = total_revenue,
    }
end

function M.sell_all_quote(player)
    local prepared, err = prepare_sell_all(player)
    if not prepared then return false, err end
    return true, prepared.total_count, prepared.total_revenue
end

function M.sell_all(player, quoted_count, quoted_revenue)
    local prepared, err = prepare_sell_all(player)
    if not prepared then return false, err end
    if quoted_count ~= nil and (prepared.total_count ~= quoted_count
            or prepared.total_revenue ~= quoted_revenue) then
        return false, 'quote-changed'
    end
    local removed = {}
    for _, entry in ipairs(prepared.settlements) do
        local actual = prepared.inventory.remove{
            name = entry.name,
            count = entry.count,
            quality = 'normal',
        }
        if actual ~= entry.count then
            for _, previous in ipairs(removed) do
                prepared.inventory.insert{
                    name = previous.name,
                    count = previous.count,
                    quality = 'normal',
                }
            end
            if actual > 0 then
                prepared.inventory.insert{
                    name = entry.name, count = actual, quality = 'normal',
                }
            end
            return false, 'inventory-changed'
        end
        removed[#removed + 1] = entry
    end
    if not economy.change(
            player.index, prepared.total_revenue, 'market-sell-all') then
        for _, entry in ipairs(removed) do
            prepared.inventory.insert{
                name = entry.name,
                count = entry.count,
                quality = 'normal',
            }
        end
        return false, 'credit-limit'
    end
    storage.local_markets[prepared.force_name] = prepared.draft
    bump_revision(prepared.force_name)
    return true, prepared.total_count, prepared.total_revenue
end

function M.deposit_property_tax(planet_name, amount)
    if not valid_nonnegative_integer(amount) then return false, 'invalid-amount' end
    if amount == 0 then return true, 0, 0 end
    local force = factions.of_planet(planet_name)
    if not (force and force.valid) then return false, 'no-faction' end
    local market = market_for_force(force.name)
    local retained, remainder = floor_with_remainder(
        amount * property_tax_market_share(),
        market.property_tax_rounding_remainder
    )
    if market.cash + retained > MAX_SAFE_INTEGER
            or market.liquidity + retained > MAX_SAFE_INTEGER then
        return false, 'credit-limit'
    end
    market.property_tax_rounding_remainder = remainder
    if retained > 0 then
        market.cash = market.cash + retained
        market.liquidity = market.liquidity + retained
        bump_revision(force.name)
    end
    return true, retained, amount - retained
end

return M
