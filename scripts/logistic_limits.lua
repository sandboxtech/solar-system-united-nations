local config = require('config')
local events = require('scripts.events')

local M = {}

local function enforce_network_limit(event)
    local entity = event.entity
    if not (entity and entity.valid and entity.type == 'roboport') then return end

    local network = entity.logistic_network
    if not (network and network.valid) then return end

    local roboport_count = #network.cells
    local logistic_robot_count = network.all_logistic_robots
    local too_many_roboports
        = roboport_count > config.logistic_network_roboport_limit
    local too_many_robots
        = logistic_robot_count > config.logistic_network_logistic_robot_limit
    if not too_many_roboports and not too_many_robots then return end

    local force = entity.force
    entity.destroy()

    if too_many_roboports and too_many_robots then
        force.print({
            'un.roboport-limit-both',
            roboport_count,
            config.logistic_network_roboport_limit,
            logistic_robot_count,
            config.logistic_network_logistic_robot_limit,
        })
    elseif too_many_roboports then
        force.print({
            'un.roboport-limit-ports',
            roboport_count,
            config.logistic_network_roboport_limit,
        })
    else
        force.print({
            'un.roboport-limit-robots',
            logistic_robot_count,
            config.logistic_network_logistic_robot_limit,
        })
    end
end

events.on(defines.events.on_built_entity, enforce_network_limit)
events.on(defines.events.on_robot_built_entity, enforce_network_limit)

return M
