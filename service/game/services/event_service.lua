local logger = require "logger"
--local achievement_service = require "services.achievement_service"
--local statistics_service = require "services.statistics_service"
--local message_service = require "services.message_service"
--local config_service = require "services.config_service"

local M = {}

-- 事件处理器映射表
local event_handlers = {
    on_item_composed = function(event_data)
        -- 1. 记录日志
        logger.info("Item composed - target_id: %d, result: %s, user_id: %d", 
            event_data.target_id,
            tostring(event_data.result or "nil"),
            event_data.user_id)
    end,
    
    on_item_decomposed = function(event_data)
        -- 1. 记录日志
        logger.info("Item decomposed - item_id: %d, count: %d, result_items: %d, user_id: %d", 
            event_data.item_id, 
            event_data.count,
            #event_data.result_items,
            event_data.user_id)
    end
}

-- 处理事件
function M.handle_event(event_name, event_data)
    local handler = event_handlers[event_name]
    if handler then
        local ok, err = xpcall(handler, debug.traceback, event_data)
        if not ok then
            logger.error("Failed to handle event %s: %s", event_name, err)
        end
    end
end

-- 注册事件处理器
function M.register_handler(event_name, handler)
    event_handlers[event_name] = handler
end

return M 