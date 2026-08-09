local M = {}

local handlers = {}

local function report_error(event_id, err)
    log('[un] event ' .. tostring(event_id) .. ' failed: ' .. tostring(err))
    if not game then return end
    for _, player in pairs(game.connected_players) do
        if player.admin then
            player.print({'un.event-error', tostring(event_id)})
        end
    end
end

function M.on(event_id, handler)
    local list = handlers[event_id]
    if not list then
        list = {}
        handlers[event_id] = list
        script.on_event(event_id, function(event)
            for _, registered in ipairs(list) do
                local ok, err = pcall(registered, event)
                if not ok then report_error(event_id, err) end
            end
        end)
    end
    list[#list + 1] = handler
end

return M
