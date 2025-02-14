local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 会话存储
local sessions = {}
local session_by_username = {}

-- 添加用户会话
function M.add_user(client_id, user_info)
    -- 检查是否已有会话
    local old_client_id = session_by_username[user_info.username]
    if old_client_id then
        -- 踢掉旧会话
        M.remove_user(old_client_id)
        logger.info("Kicked old session for user: %s", user_info.username)
    end
    
    -- 添加新会话
    sessions[client_id] = {
        user_info = user_info,
        login_time = os.time()
    }
    session_by_username[user_info.username] = client_id
    
    logger.info("User logged in - username: %s, client_id: %s", 
        user_info.username, client_id)
end

-- 删除用户会话
function M.remove_user(client_id)
    local session = sessions[client_id]
    if session then
        local username = session.user_info.username
        session_by_username[username] = nil
        logger.info("User logged out - username: %s, client_id: %s", 
            username, client_id)
    end
    sessions[client_id] = nil
end

-- 获取用户会话
function M.get_session(client_id)
    return sessions[client_id]
end

-- 检查用户是否在线
function M.is_user_online(username)
    return session_by_username[username] ~= nil
end

-- 获取会话统计信息
function M.get_stats()
    local online_count = 0
    local online_users = {}
    for client_id, session in pairs(sessions) do
        online_count = online_count + 1
        table.insert(online_users, {
            username = session.user_info.username,
            client_id = client_id,
            login_time = session.login_time
        })
    end
    
    return {
        online_users = online_count,
        online_list = online_users
    }
end

return M 