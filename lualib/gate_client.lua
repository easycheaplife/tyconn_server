-- gate_client.lua - 网关客户端模块，用于向客户端推送消息
local skynet = require "skynet"
local logger = require "logger"
local user_session_service = require "services.user_session_service"

local M = {}

-- 推送消息到指定用户
function M.push_message(user_id, message_id, message_data)
    local gate_addr = skynet.call(".login", "lua", "get_gate_by_userid", user_id)
    if not gate_addr then
        logger.warn("User %d not connected to any gate", user_id)
        return false
    end

    local ok, err = pcall(function()
        skynet.send(gate_addr, "lua", "push", user_id, message_id, message_data)
    end)

    if not ok then
        logger.error("Failed to push message to user %d: %s", user_id, err)
        return false
    end
    
    return true
end

-- 批量推送消息到指定用户列表
function M.push_message_to_users(user_ids, message_id, message_data)
    if not user_ids or #user_ids == 0 then
        return true
    end
    
    local result = true
    for _, user_id in ipairs(user_ids) do
        local ok = M.push_message(user_id, message_id, message_data)
        if not ok then
            result = false
        end
    end
    
    return result
end

-- 广播消息到所有在线用户
function M.broadcast_message(message_id, message_data)
    local online_users = user_session_service.get_all_online_user_ids()
    
    return M.push_message_to_users(online_users, message_id, message_data)
end

return M 