-- online_service.lua - 在线用户服务
local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 在线用户表，key为用户ID，value为连接信息
local online_users = {}

-- 登录成功，记录用户在线状态
function M.login(user_id, conn_info)
    if not user_id then
        return false
    end
    
    online_users[user_id] = conn_info or {
        login_time = os.time(),
        last_active = os.time()
    }
    
    logger.info("User %d logged in", user_id)
    return true
end

-- 用户登出，清除在线状态
function M.logout(user_id)
    if not user_id or not online_users[user_id] then
        return false
    end
    
    online_users[user_id] = nil
    logger.info("User %d logged out", user_id)
    return true
end

-- 更新用户活动时间
function M.touch(user_id)
    if not user_id or not online_users[user_id] then
        return false
    end
    
    online_users[user_id].last_active = os.time()
    return true
end

-- 检查用户是否在线
function M.is_online(user_id)
    return user_id and online_users[user_id] ~= nil
end

-- 获取用户在线信息
function M.get_user_online_info(user_id)
    return online_users[user_id]
end

-- 获取所有在线用户ID
function M.get_all_online_users()
    local users = {}
    for user_id, _ in pairs(online_users) do
        table.insert(users, user_id)
    end
    return users
end

-- 获取在线用户数量
function M.get_online_count()
    local count = 0
    for _, _ in pairs(online_users) do
        count = count + 1
    end
    return count
end

-- 清理长时间不活跃的用户
function M.clean_inactive_users(timeout)
    timeout = timeout or 1800  -- 默认30分钟
    local now = os.time()
    local removed = 0
    
    for user_id, info in pairs(online_users) do
        if now - info.last_active > timeout then
            online_users[user_id] = nil
            removed = removed + 1
            logger.info("Removed inactive user %d", user_id)
        end
    end
    
    return removed
end

-- 初始化服务
function M.init()
    -- 定期清理不活跃用户
    skynet.fork(function()
        while true do
            skynet.sleep(600 * 100)  -- 10分钟检查一次
            local removed = M.clean_inactive_users()
            if removed > 0 then
                logger.info("Cleaned %d inactive users", removed)
            end
        end
    end)
    
    logger.info("Online service initialized")
    return true
end

return M 