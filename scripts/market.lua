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
assert(config.market_depth_value > 0,
    'market_depth_value must be greater than zero')
assert(config.market_sell_fee_rate >= 0 and config.market_sell_fee_rate < 1,
    'market_sell_fee_rate must be between zero and one')
assert(config.market_tax_share >= 0 and config.market_tax_share <= 1,
    'market_tax_share must be between zero and one')

local function valid_number(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_nonnegative_integer(value)
    return valid_number(value) and value >= 0 and value == math.floor(value)
end

local function valid_count(value)
    return valid_nonnegative_integer(value) and value > 0
end

local function valid_remainder(value, minimum, maximum)
    return valid_number(value) and value >= minimum and value <= maximum
end

local function market_depth(spec)
    return config.market_depth_value / spec.base_price
end

local function initial_stock()
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        result[spec.name] = 0
    end
    return result
end

local function initial_market()
    return {
        cash = config.market_initial_cash,
        liquidity = config.market_initial_cash,
        stock = initial_stock(),
        buy_rounding_remainder = 0,
        sell_gross_rounding_remainder = 0,
        sell_fee_rounding_remainder = 0,
        tax_rounding_remainder = 0,
    }
end

local function ensure_curve()
    if storage.market_curve_version == config.market_curve_version then return end
    storage.local_markets = {}
    storage.market_curve_version = config.market_curve_version
    storage.market_revisions = {}
end

local function normalize_market(market)
    if not valid_nonnegative_integer(market.cash)
            or market.cash > MAX_SAFE_INTEGER then
        market.cash = config.market_initial_cash
    end
    if not valid_number(market.liquidity) or market.liquidity <= 0
            or market.liquidity > MAX_SAFE_INTEGER then
        market.liquidity = math.max(market.cash, 0.000000001)
    end
    if type(market.stock) ~= 'table' then market.stock = initial_stock() end
    for _, spec in ipairs(config.market_items or {}) do
        if not valid_nonnegative_integer(market.stock[spec.name]) then
            market.stock[spec.name] = 0
        end
    end
    if not valid_remainder(market.buy_rounding_remainder, -1, 0) then
        market.buy_rounding_remainder = 0
    end
    if not valid_remainder(market.sell_gross_rounding_remainder, 0, 1) then
        market.sell_gross_rounding_remainder = 0
    end
    if not valid_remainder(market.sell_fee_rounding_remainder, 0, 1) then
        market.sell_fee_rounding_remainder = 0
    end
    if not valid_remainder(market.tax_rounding_remainder, 0, 1) then
        market.tax_rounding_remainder = 0
    end
    return market
end

local function market_for_force(force_name)
    ensure_curve()
    local market = storage.local_markets[force_name]
    if type(market) ~= 'table' then
        market = initial_market()
        storage.local_markets[force_name] = market
    end
    return normalize_market(market)
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

local function inventory_price_factor(spec, stock)
    return 1 / (1 + stock / market_depth(spec))
end

local function base_spot_price(spec, stock)
    return spec.base_price * inventory_price_factor(spec, stock)
end

local function spot_price(market, spec, stock)
    return base_spot_price(spec, stock)
        * market.liquidity / config.market_initial_cash
end

-- Integral of the inventory-only price curve over [lower_stock, upper_stock].
local function inventory_curve_value(spec, lower_stock, upper_stock)
    if lower_stock < 0 or upper_stock <= lower_stock then return nil end
    local depth = market_depth(spec)
    local raw = config.market_depth_value * math.log(
        (1 + upper_stock / depth) / (1 + lower_stock / depth)
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

local function tax_share()
    return settings.get('market_tax_share_percent') / 100
end

local function buy_settlement(market, spec, count)
    local stock = market.stock[spec.name]
    if count > stock then return nil, 'out-of-stock' end
    local curve_value = inventory_curve_value(spec, stock - count, stock)
    if not curve_value then return nil, 'no-value' end
    local multiplier = math.exp(curve_value / config.market_initial_cash)
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
    local curve_value = inventory_curve_value(spec, stock, stock + count)
    if not curve_value then return nil, 'no-value' end
    local fee_rate = config.market_sell_fee_rate
    local share = tax_share()
    local cash_factor = 1 - fee_rate * share
    local next_liquidity = market.liquidity
        * math.exp(-cash_factor * curve_value / config.market_initial_cash)
    if not valid_number(next_liquidity) or next_liquidity <= 0 then
        return nil, 'no-value'
    end
    local raw_gross = (market.liquidity - next_liquidity) / cash_factor
    if not valid_number(raw_gross) or raw_gross <= 0
            or raw_gross > MAX_SAFE_INTEGER then
        return nil, 'no-value'
    end
    local gross, gross_remainder = floor_with_remainder(
        raw_gross,
        market.sell_gross_rounding_remainder
    )
    local fee, fee_remainder = floor_with_remainder(
        raw_gross * fee_rate,
        market.sell_fee_rounding_remainder
    )
    fee = math.min(gross, fee)
    local retained_tax, tax_remainder = floor_with_remainder(
        fee * share,
        market.tax_rounding_remainder
    )
    retained_tax = math.min(fee, retained_tax)
    local revenue = gross - fee
    local market_cost = gross - retained_tax
    if revenue <= 0 then return nil, 'no-value' end
    if market_cost > market.cash then
        return nil, 'insufficient-market-credit'
    end
    return {
        count = count,
        revenue = revenue,
        fee = fee,
        gross = gross,
        retained_tax = retained_tax,
        market_cost = market_cost,
        next_liquidity = next_liquidity,
        gross_remainder = gross_remainder,
        fee_remainder = fee_remainder,
        tax_remainder = tax_remainder,
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
    market.cash = market.cash - settlement.market_cost
    market.liquidity = settlement.next_liquidity
    market.sell_gross_rounding_remainder = settlement.gross_remainder
    market.sell_fee_rounding_remainder = settlement.fee_remainder
    market.tax_rounding_remainder = settlement.tax_remainder
end

local function copy_market(market)
    local result = {}
    for key, value in pairs(market) do
        if key ~= 'stock' then result[key] = value end
    end
    result.stock = {}
    for name, count in pairs(market.stock) do result.stock[name] = count end
    return result
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

function M.price(player_index, item_name)
    local spec = item_specs[item_name]
    if not spec then return nil end
    local market = market_for_player_index(player_index)
    if not market then return nil end
    return math.max(1, math.ceil(spot_price(
        market,
        spec,
        market.stock[item_name]
    )))
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

function M.sell_from_inventory(player_index, item_name, inventory, maximum)
    if not (inventory and inventory.valid) then return false, 'no-inventory' end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player_index(player_index)
    if not market then return false, force_name end
    local carried = inventory.get_item_count{
        name = item_name, quality = 'normal',
    }
    local count = math.min(carried, math.max(1, math.floor(maximum or carried)))
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
    if not economy.change(player_index, settlement.revenue, 'market-auto-sell') then
        inventory.insert{name = item_name, count = count, quality = 'normal'}
        return false, 'credit-limit'
    end
    apply_sell(market, item_name, settlement)
    bump_revision(force_name)
    return true, count, settlement.revenue, settlement.fee
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
    return true, count, settlement.revenue, settlement.fee
end

function M.sell_all(player)
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end
    local draft = copy_market(market)
    local settlements = {}
    local total_count = 0
    local total_revenue = 0
    local total_fee = 0
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
                total_fee = total_fee + settlement.fee
            elseif err == 'insufficient-market-credit' then
                return false, err
            end
        end
    end
    if total_count <= 0 then return false, 'nothing-to-sell' end
    local removed = {}
    for _, entry in ipairs(settlements) do
        local actual = inventory.remove{
            name = entry.name,
            count = entry.count,
            quality = 'normal',
        }
        if actual ~= entry.count then
            for _, previous in ipairs(removed) do
                inventory.insert{
                    name = previous.name,
                    count = previous.count,
                    quality = 'normal',
                }
            end
            if actual > 0 then
                inventory.insert{
                    name = entry.name, count = actual, quality = 'normal',
                }
            end
            return false, 'inventory-changed'
        end
        removed[#removed + 1] = entry
    end
    if not economy.change(player.index, total_revenue, 'market-sell-all') then
        for _, entry in ipairs(removed) do
            inventory.insert{
                name = entry.name,
                count = entry.count,
                quality = 'normal',
            }
        end
        return false, 'credit-limit'
    end
    storage.local_markets[force_name] = draft
    bump_revision(force_name)
    return true, total_count, total_revenue, total_fee
end

function M.deposit_tax(planet_name, amount)
    if not valid_nonnegative_integer(amount) then return false, 'invalid-amount' end
    if amount == 0 then return true, 0, 0 end
    local force = factions.of_planet(planet_name)
    if not (force and force.valid) then return false, 'no-faction' end
    local market = market_for_force(force.name)
    local retained, remainder = floor_with_remainder(
        amount * tax_share(),
        market.tax_rounding_remainder
    )
    if market.cash + retained > MAX_SAFE_INTEGER
            or market.liquidity + retained > MAX_SAFE_INTEGER then
        return false, 'credit-limit'
    end
    market.tax_rounding_remainder = remainder
    if retained > 0 then
        market.cash = market.cash + retained
        market.liquidity = market.liquidity + retained
        bump_revision(force.name)
    end
    return true, retained, amount - retained
end

return M
