local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"

local M = {}

-- 会话存储
local sessions = {
    by_client = {},     -- client_id -> session
    by_account = {},    -- account -> client_id
    by_user_id = {}     -- user_id -> session
}

-- 会话数据结构
local function create_session(client_id, user_info, gate_node)
    logger.debug("Creating session - client_id: %s, account: %s, gate_node: %s", 
        client_id, user_info.account, tostring(gate_node))
    
    local session = {
        client_id = client_id,
        user_id = user_info.user_id,
        account = user_info.account,
        login_time = os.time(),
        last_active = os.time(),
        user_info = user_info,
        gate_node = gate_node
    }
    
    -- 尝试预解析网关地址
    if gate_node then
        local ok, gate_addr = pcall(function()
            -- 先尝试本地名称
            local addr = skynet.localname("." .. gate_node)
            if addr then
                return addr
            end
            
            -- 尝试集群查询
            local ok, addr = pcall(function()
                return skynet.call(".cluster", "lua", "query", gate_node, "gate")
            end)
            if ok and addr then
                return addr
            end
            
            -- 直接构造地址 (最后的尝试)
            if string.match(gate_node, "^gate%d+$") then
                return "@" .. gate_node
            end
            
            return nil
        end)
        
        if ok and gate_addr then
            session.gate_addr = gate_addr
            logger.debug("Pre-resolved gate address for node %s: %s", gate_node, tostring(gate_addr))
        else
            logger.warn("Failed to pre-resolve gate address for node %s", gate_node)
        end
    end
    
    return session
end

-- 添加用户会话
function M.add_user(client_id, user_info, gate_node)
    -- 检查用户是否已经在线
    local old_client_id = sessions.by_account[user_info.account]
    if old_client_id then
        -- 踢掉旧的连接
        M.remove_user(old_client_id)
        logger.info("Kicked old session for account: %s", user_info.account)
    end
    
    -- 创建新会话
    local session = create_session(client_id, user_info, gate_node)
    
    -- 添加索引
    sessions.by_client[client_id] = session
    sessions.by_account[user_info.account] = client_id
    sessions.by_user_id[user_info.user_id] = session
    
    -- 更新最后登录时间
    user_info.last_login = session.login_time
    
    logger.info("User logged in - account: %s, user_id: %d, client_id: %s", 
        user_info.account, user_info.user_id, client_id)
        
    return true
end

-- 删除用户会话
function M.remove_user(client_id)
    local session = sessions.by_client[client_id]
    if session then
        -- 清理所有索引
        sessions.by_client[client_id] = nil
        sessions.by_account[session.account] = nil
        sessions.by_user_id[session.user_id] = nil
        
        logger.info("User logged out - account: %s, user_id: %d, client_id: %s", 
            session.account, session.user_id, client_id)
    end
end

-- 更新用户活动时间
function M.touch(client_id)
    local session = sessions.by_client[client_id]
    if session then
        session.last_active = os.time()
        return true
    end
    return false
end

-- 获取会话信息
function M.get_session(client_id)
    return sessions.by_client[client_id]
end

-- 通过用户ID获取会话
function M.get_session_by_user_id(user_id)
    return sessions.by_user_id[user_id]
end

-- 通过账号获取会话
function M.get_session_by_account(account)
    local client_id = sessions.by_account[account]
    if client_id then
        return sessions.by_client[client_id]
    end
    return nil
end

-- 检查用户是否在线
function M.is_online(account)
    return sessions.by_account[account] ~= nil
end

function M.is_user_id_online(user_id)
    return sessions.by_user_id[user_id] ~= nil
end

-- 获取所有在线用户ID
function M.get_all_online_user_ids()
    local users = {}
    for user_id, _ in pairs(sessions.by_user_id) do
        table.insert(users, user_id)
    end
    return users
end

-- 获取在线用户数量
function M.get_online_count()
    local count = 0
    for _, _ in pairs(sessions.by_client) do
        count = count + 1
    end
    return count
end

-- 获取会话统计信息
function M.get_stats()
    local online_users = {}
    for _, session in pairs(sessions.by_client) do
        table.insert(online_users, {
            account = session.account,
            user_id = session.user_id,
            client_id = session.client_id,
            login_time = session.login_time,
            last_active = session.last_active
        })
    end
    
    return {
        online_count = #online_users,
        online_users = online_users
    }
end

-- 清理不活跃用户
local function clean_inactive_users(timeout)
    timeout = timeout or 1800  -- 默认30分钟
    local now = os.time()
    local removed = 0
    
    for client_id, session in pairs(sessions.by_client) do
        if now - session.last_active > timeout then
            M.remove_user(client_id)
            removed = removed + 1
            logger.info("Removed inactive user: %s", session.account)
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
            local removed = clean_inactive_users()
            if removed > 0 then
                logger.info("Cleaned %d inactive users", removed)
            end
        end
    end)
    
    -- 定期打印在线人数
    skynet.fork(function()
        while true do
            skynet.sleep(60 * 100)  -- 60秒检查一次
            local stats = M.get_stats()
            logger.info("Current online users: %d", stats.online_count)
        end
    end)
    
    logger.info("User session service initialized")
    return true
end

return M 