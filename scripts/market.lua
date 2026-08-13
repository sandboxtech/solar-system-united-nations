local config = require('config')
local economy = require('scripts.economy')
local factions = require('scripts.factions')
local state = require('scripts.state')
local surfaces = require('scripts.surfaces')

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
assert(config.market_depth_value > 0,
    'market_depth_value must be greater than zero')
assert(config.market_depth_price_multiplier > 1,
    'market_depth_price_multiplier must be greater than one')
assert(config.market_sell_fee_rate >= 0 and config.market_sell_fee_rate < 1,
    'market_sell_fee_rate must be between zero and one')

local function valid_number(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_count(value)
    return type(value) == 'number' and value > 0
        and value == math.floor(value)
end

local function market_depth(spec)
    return config.market_depth_value / spec.base_price
end

local function initial_market()
    local result = {}
    for _, spec in ipairs(config.market_items or {}) do
        result[spec.name] = 0
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
        if not valid_number(market[spec.name]) then
            market[spec.name] = 0
        end
    end
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

local function curve_exponent(spec, stock)
    return -stock / market_depth(spec)
end

local function spot_price(spec, stock)
    return spec.base_price * config.market_depth_price_multiplier
        ^ curve_exponent(spec, stock)
end

local function integral_scale(spec)
    return spec.base_price * market_depth(spec)
        / math.log(config.market_depth_price_multiplier)
end

local function buy_cost(spec, stock, count)
    if count <= 0 then return nil end
    local raw = integral_scale(spec) * (
        config.market_depth_price_multiplier
            ^ curve_exponent(spec, stock - count)
        - config.market_depth_price_multiplier
            ^ curve_exponent(spec, stock)
    )
    if not valid_number(raw) or raw > MAX_SAFE_INTEGER then return nil end
    return math.max(1, math.ceil(raw))
end

local function sell_revenue(spec, stock, count)
    if count <= 0 then return nil end
    local raw = integral_scale(spec) * (
        config.market_depth_price_multiplier
            ^ curve_exponent(spec, stock)
        - config.market_depth_price_multiplier
            ^ curve_exponent(spec, stock + count)
    )
    if not valid_number(raw) or raw > MAX_SAFE_INTEGER then return nil end
    return math.floor(raw)
end

local function sell_settlement(spec, stock, count)
    local gross = sell_revenue(spec, stock, count)
    if not gross or gross <= 0 then return nil end
    local fee = math.floor(gross * config.market_sell_fee_rate)
    return gross - fee, fee, gross
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
        local stock = math.floor(market[spec.name])
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

function M.is_tradable(item_name)
    return item_specs[item_name] ~= nil
end

function M.price(player_index, item_name)
    local spec = item_specs[item_name]
    if not spec then return nil end
    local market = market_for_player_index(player_index)
    if not market then return nil end
    local stock = math.floor(market[item_name])
    return math.max(1, math.ceil(spot_price(spec, stock)))
end

function M.buy_quote(player, item_name, count)
    if not valid_count(count) then return nil, 'invalid-count' end
    local spec = item_specs[item_name]
    if not spec then return nil, 'invalid-item' end
    local market, err = market_for_player(player)
    if not market then return nil, err end
    local stock = math.floor(market[item_name])
    local cost = buy_cost(spec, stock, count)
    if not cost then return nil, 'no-value' end
    return cost
end

function M.buy_into_inventory(player_index, item_name, count, inventory)
    if not valid_count(count) or not (inventory and inventory.valid) then
        return false, 'invalid-count'
    end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player_index(player_index)
    if not market then return false, force_name end
    local stock = math.floor(market[item_name])
    local insertable = inventory.get_insertable_count{
        name = item_name, quality = 'normal',
    }
    count = math.min(count, insertable)
    if count <= 0 then return false, 'inventory-full' end
    local balance = economy.get_balance(player_index)
    local cost = buy_cost(spec, stock, count)
    while count > 0 and (not cost or cost > balance) do
        count = math.floor(count / 2)
        cost = count > 0 and buy_cost(spec, stock, count) or nil
    end
    if count <= 0 or not cost then return false, 'insufficient-credit' end
    local inserted = inventory.insert{
        name = item_name, count = count, quality = 'normal',
    }
    if inserted ~= count then
        if inserted > 0 then
            inventory.remove{name = item_name, count = inserted, quality = 'normal'}
        end
        return false, 'inventory-full'
    end
    if not economy.change(player_index, -cost, 'market-auto-buy') then
        inventory.remove{name = item_name, count = count, quality = 'normal'}
        return false, 'insufficient-credit'
    end
    market[item_name] = stock - count
    bump_revision(force_name)
    return true, count, cost
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
    local stock = math.floor(market[item_name])
    local revenue, fee = sell_settlement(spec, stock, count)
    if not revenue or revenue <= 0 then return false, 'no-value' end
    local removed = inventory.remove{
        name = item_name, count = count, quality = 'normal',
    }
    if removed ~= count then return false, 'inventory-changed' end
    if not economy.change(player_index, revenue, 'market-auto-sell') then
        inventory.insert{name = item_name, count = count, quality = 'normal'}
        return false, 'credit-limit'
    end
    market[item_name] = stock + count
    bump_revision(force_name)
    return true, count, revenue, fee
end

function M.buy(player, item_name, requested)
    if not valid_count(requested) then return false, 'invalid-count' end
    local spec = item_specs[item_name]
    if not spec then return false, 'invalid-item' end
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end

    local stock = math.floor(market[item_name])
    local insertable = inventory.get_insertable_count{
        name = item_name,
        quality = 'normal',
    }
    if insertable < requested then return false, 'inventory-full' end
    local balance = economy.get_balance(player.index)
    local count = requested
    local cost = buy_cost(spec, stock, count)
    if not cost or cost > balance then return false, 'insufficient-credit' end
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
    local stock = math.floor(market[item_name])
    local revenue, fee = sell_settlement(spec, stock, count)
    if not revenue or revenue <= 0 then return false, 'no-value' end
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
    market[item_name] = stock + count
    bump_revision(force_name)
    return true, count, revenue, fee
end

function M.sell_all(player)
    local market, force_name = market_for_player(player)
    if not market then return false, force_name end
    local inventory = main_inventory(player)
    if not inventory then return false, 'no-inventory' end
    local total_count = 0
    local total_revenue = 0
    local total_fee = 0
    for _, spec in ipairs(config.market_items or {}) do
        local count = inventory.get_item_count{
            name = spec.name,
            quality = 'normal',
        }
        if count > 0 then
            local stock = math.floor(market[spec.name])
            local revenue, fee = sell_settlement(spec, stock, count)
            if revenue and revenue > 0 then
                total_count = total_count + count
                total_revenue = total_revenue + revenue
                total_fee = total_fee + fee
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
            local stock = math.floor(market[spec.name])
            local revenue, fee = sell_settlement(spec, stock, count)
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
                    fee = fee,
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
    for _, entry in ipairs(removed) do
        market[entry.name] = entry.stock + entry.count
    end
    bump_revision(force_name)
    return true, total_count, total_revenue, total_fee
end

return M
