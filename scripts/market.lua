local config = require('config')
local economy = require('scripts.economy')
local factions = require('scripts.factions')
local stamina = require('scripts.stamina')
local state = require('scripts.state')

local M = {}

local MAX_SAFE_INTEGER = 9007199254740991
local item_specs = {}

for _, spec in ipairs(config.market_items or {}) do
    assert(type(spec.name) == 'string' and spec.name ~= '',
        'market item name must not be empty')
    assert(type(spec.base_price) == 'number' and spec.base_price > 0,
        'market base_price must be greater than zero: ' .. spec.name)
    assert(not item_specs[spec.name], 'duplicate market item: ' .. spec.name)
    item_specs[spec.name] = spec
end
assert(config.market_empty_price_multiplier > 1,
    'market_empty_price_multiplier must be greater than one')

local function valid_number(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_count(value)
    return type(value) == 'number' and value > 0
        and value == math.floor(value)
end

local function initial_stock(spec)
    return math.max(1, math.floor(
        config.market_initial_stock_value / spec.base_price
    ))
end

local function initial_market()
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        result[spec.name] = initial_stock(spec)
    end
    return result
end

local function ensure_curve()
    if storage.market_curve_version == config.market_curve_version then return end
    storage.local_markets = {}
    storage.market_curve_version = config.market_curve_version
    storage.market_revisions = {}
end

local function market_for_force(force_name)
    ensure_curve()
    local market = storage.local_markets[force_name]
    if type(market) ~= 'table' then
        market = initial_market()
        storage.local_markets[force_name] = market
    end
    for _, spec in ipairs(config.market_items or {}) do
        if type(market[spec.name]) ~= 'number' or market[spec.name] < 0 then
            market[spec.name] = initial_stock(spec)
        end
    end
    return market
end

local function market_for_player(player)
    local planet_name = player and factions.of_player(player)
    local force = planet_name and factions.of_planet(planet_name)
    if not (force and player.force == force) then return nil, 'no-faction' end
    return market_for_force(force.name), force.name
end

local function curve_exponent(spec, stock)
    local stock_at_base_price = initial_stock(spec)
    return (stock_at_base_price - stock) / stock_at_base_price
end

local function spot_price(spec, stock)
    return spec.base_price * config.market_empty_price_multiplier
        ^ curve_exponent(spec, stock)
end

local function integral_scale(spec)
    return spec.base_price * initial_stock(spec)
        / math.log(config.market_empty_price_multiplier)
end

local function buy_cost(spec, stock, count)
    if count <= 0 or count > stock then return nil end
    local raw = integral_scale(spec) * (
        config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock - count)
        - config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock)
    )
    if not valid_number(raw) or raw > MAX_SAFE_INTEGER then return nil end
    return math.max(1, math.ceil(raw))
end

local function sell_revenue(spec, stock, count)
    if count <= 0 then return nil end
    local raw = integral_scale(spec) * (
        config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock)
        - config.market_empty_price_multiplier
            ^ curve_exponent(spec, stock + count)
    )
    if not valid_number(raw) or raw > MAX_SAFE_INTEGER then return nil end
    return math.floor(raw)
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

function M.list(player)
    local market, force_name = market_for_player(player)
    if not market then return nil, force_name end
    local inventory = main_inventory(player)
    if not inventory then return nil, 'no-inventory' end
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        local stock = math.max(0, math.floor(market[spec.name]))
        result[#result + 1] = {
            name = spec.name,
            group = spec.group,
            stock = stock,
            price = spot_price(spec, stock),
            carried = inventory.get_item_count{
                name = spec.name,
                quality = 'normal',
            },
        }
    end
    return result, force_name
end

function M.buy(player, item_name, requested)
    if not valid_count(requested) then return false, 'invalid-count' end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end

    local stock = math.max(0, math.floor(market[item_name]))
    local insertable = inventory.get_insertable_count{
        name = item_name,
        quality = 'normal',
    }
    if stock < requested then return false, 'out-of-stock' end
    if insertable < requested then return false, 'inventory-full' end
    local balance = economy.get_balance(player.index)
    local count = requested
    local cost = buy_cost(spec, stock, count)
    if not cost or cost > balance then return false, 'insufficient-credit' end
    if stamina.get(player.index) < config.market_trade_stamina_cost then
        return false, 'insufficient-stamina'
    end
    local inserted = inventory.insert{
        name = item_name,
        count = count,
        quality = 'normal',
    }
    if inserted ~= count then
        if inserted > 0 then
            inventory.remove{name = item_name, count = inserted, quality = 'normal'}
        end
        return false, 'inventory-full'
    end
    local paid = economy.change(player.index, -cost, 'market-buy')
    if not paid then
        inventory.remove{name = item_name, count = count, quality = 'normal'}
        return false, 'insufficient-credit'
    end
    if not stamina.spend(player.index, config.market_trade_stamina_cost) then
        economy.change(player.index, cost, 'market-buy-refund')
        inventory.remove{name = item_name, count = count, quality = 'normal'}
        return false, 'insufficient-stamina'
    end
    market[item_name] = stock - count
    bump_revision(force_name)
    return true, count, cost
end

function M.sell(player, item_name)
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end
    local count = inventory.get_item_count{
        name = item_name,
        quality = 'normal',
    }
    if count <= 0 then return false, 'nothing-to-sell' end
    local stock = math.max(0, math.floor(market[item_name]))
    local revenue = sell_revenue(spec, stock, count)
    if not revenue or revenue <= 0 then return false, 'no-value' end
    if stamina.get(player.index) < config.market_trade_stamina_cost then
        return false, 'insufficient-stamina'
    end
    local removed = inventory.remove{
        name = item_name,
        count = count,
        quality = 'normal',
    }
    if removed ~= count then
        if removed > 0 then
            inventory.insert{name = item_name, count = removed, quality = 'normal'}
        end
        return false, 'inventory-changed'
    end
    local paid = economy.change(player.index, revenue, 'market-sell')
    if not paid then
        inventory.insert{name = item_name, count = count, quality = 'normal'}
        return false, 'credit-limit'
    end
    if not stamina.spend(player.index, config.market_trade_stamina_cost) then
        economy.change(player.index, -revenue, 'market-sell-refund')
        inventory.insert{name = item_name, count = count, quality = 'normal'}
        return false, 'insufficient-stamina'
    end
    market[item_name] = stock + count
    bump_revision(force_name)
    return true, count, revenue
end

function M.sell_all(player)
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end
    if stamina.get(player.index) < config.market_trade_stamina_cost then
        return false, 'insufficient-stamina'
    end
    local total_count = 0
    local total_revenue = 0
    for _, spec in ipairs(config.market_items or {}) do
        local count = inventory.get_item_count{
            name = spec.name,
            quality = 'normal',
        }
        if count > 0 then
            local stock = math.max(0, math.floor(market[spec.name]))
            local revenue = sell_revenue(spec, stock, count)
            if revenue and revenue > 0 then
                total_count = total_count + count
                total_revenue = total_revenue + revenue
            end
        end
    end
    if total_count <= 0 then return false, 'nothing-to-sell' end
    local removed = {}
    for _, spec in ipairs(config.market_items or {}) do
        local count = inventory.get_item_count{
            name = spec.name,
            quality = 'normal',
        }
        if count > 0 then
            local stock = math.max(0, math.floor(market[spec.name]))
            local revenue = sell_revenue(spec, stock, count)
            if revenue and revenue > 0 then
                local actual = inventory.remove{
                    name = spec.name,
                    count = count,
                    quality = 'normal',
                }
                if actual ~= count then
                    for _, entry in ipairs(removed) do
                        inventory.insert{
                            name = entry.name,
                            count = entry.count,
                            quality = 'normal',
                        }
                    end
                    if actual > 0 then
                        inventory.insert{name = spec.name, count = actual,
                            quality = 'normal'}
                    end
                    return false, 'inventory-changed'
                end
                removed[#removed + 1] = {
                    name = spec.name,
                    count = count,
                    quality = 'normal',
                    revenue = revenue,
                    stock = stock,
                }
            end
        end
    end
    local paid = economy.change(player.index, total_revenue, 'market-sell-all')
    if not paid then
        for _, entry in ipairs(removed) do
            inventory.insert{
                name = entry.name,
                count = entry.count,
                quality = 'normal',
            }
        end
        return false, 'credit-limit'
    end
    if not stamina.spend(player.index, config.market_trade_stamina_cost) then
        economy.change(player.index, -total_revenue, 'market-sell-all-refund')
        for _, entry in ipairs(removed) do
            inventory.insert{
                name = entry.name,
                count = entry.count,
                quality = 'normal',
            }
        end
        return false, 'insufficient-stamina'
    end
    for _, entry in ipairs(removed) do
        market[entry.name] = entry.stock + entry.count
    end
    bump_revision(force_name)
    return true, total_count, total_revenue
end

return M
