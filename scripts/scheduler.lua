local M = {}

local handlers = {}

local function report_error(interval, err)
    log('[un] scheduler ' .. tostring(interval) .. ' failed: ' .. tostring(err))
    if not game then return end
    for _, player in pairs(game.connected_players) do
        if player.admin then
            player.print({'un.scheduler-error', tostring(interval)})
        end
    end
end

function M.every(interval, handler)
    assert(type(interval) == 'number' and interval > 0, 'invalid scheduler interval')
    local list = handlers[interval]
    if not list then
        list = {}
        handlers[interval] = list
        script.on_nth_tick(interval, function(event)
            for _, registered in ipairs(list) do
                local ok, err = pcall(registered, event)
                if not ok then report_error(interval, err) end
            end
        end)
    end
    list[#list + 1] = handler
end

return M
