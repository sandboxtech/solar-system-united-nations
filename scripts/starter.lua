local config = require('config')
local events = require('scripts.events')
local state = require('scripts.state')
local stamina = require('scripts.stamina')

local M = {}

local function deliver_item(player, item)
    if type(item) ~= 'table' or type(item.name) ~= 'string' then return 0 end
    local count = tonumber(item.count) or 0
    if count ~= count or count == math.huge or count == -math.huge then return 0 end
    count = math.max(0, math.floor(count))
    if count == 0 or not prototypes.item[item.name] then return 0 end
    local inserted = player.insert{name = item.name, count = count}
    local remainder = count - inserted
    if remainder > 0 then
        player.physical_surface.spill_item_stack{
            position = player.physical_position,
            stack = {name = item.name, count = remainder},
            enable_looted = true,
            allow_belts = false,
        }
    end
    return count
end

local function equipment_valid()
    if not prototypes.item[config.starter_kit_armor] then return false end
    for _, item in ipairs(config.starter_kit_equipment) do
        if not prototypes.item[item.name]
                or not prototypes.equipment[item.name] then
            return false
        end
    end
    for _, item in ipairs(config.starter_kit_items) do
        if not prototypes.item[item.name] then return false end
    end
    return true
end

local function deliver_kit(player)
    local armor_inventory = player.get_inventory(
        defines.inventory.character_armor
    )
    local armor = armor_inventory and armor_inventory[1]
    local equipped = armor and not armor.valid_for_read
    if equipped then
        armor.set_stack{name = config.starter_kit_armor, count = 1}
        equipped = armor.valid_for_read
    end

    if not equipped then
        deliver_item(player, {name = config.starter_kit_armor, count = 1})
    end

    local grid = equipped and armor.grid or nil
    for _, item in ipairs(config.starter_kit_equipment) do
        for _ = 1, item.count do
            if not (grid and grid.put{name = item.name}) then
                deliver_item(player, {name = item.name, count = 1})
            end
        end
    end
    for _, item in ipairs(config.starter_kit_items) do
        deliver_item(player, item)
    end
end

function M.can_buy(player)
    if not (player and player.valid and player.character
            and player.character.valid) then
        return false, 'unavailable'
    end
    if not equipment_valid() then return false, 'invalid-kit' end
    if stamina.get(player.index) < config.starter_kit_stamina_cost then
        return false, 'insufficient-stamina'
    end
    return true
end

function M.buy(player)
    local available, err = M.can_buy(player)
    if not available then return false, err end
    if not stamina.spend(player.index, config.starter_kit_stamina_cost) then
        return false, 'insufficient-stamina'
    end
    deliver_kit(player)
    return true
end

function M.can_buy_wood(player)
    if not (player and player.valid and player.character
            and player.character.valid and prototypes.item.wood) then
        return false, 'unavailable'
    end
    if stamina.get(player.index) < config.wood_supply_stamina_cost then
        return false, 'insufficient-stamina'
    end
    return true
end

function M.buy_wood(player)
    local available, err = M.can_buy_wood(player)
    if not available then return false, err end
    if not stamina.spend(player.index, config.wood_supply_stamina_cost) then
        return false, 'insufficient-stamina'
    end
    deliver_item(player, {name = 'wood', count = config.wood_supply_count})
    return true
end

events.on(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    state.ensure()
    local resources = type(storage.starter_resources) == 'table'
        and storage.starter_resources or config.starter_resources
    for _, item in ipairs(resources) do
        deliver_item(player, item)
    end
    player.print({'un.starter-resources-granted'})
end)

return M
