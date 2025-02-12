local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local utils = require "utils"
local db_client = require "game.db_client"
local cache = require "game.cache"

local M = {}

-- 用户会话管理
local sessions = {}  -- client_id -> session
local session_by_username = {}  -- username -> client_id

-- 调用数据库代理
local function call_db(...)
    return cluster.call("db_proxy", "@db_proxy", ...)
end

-- 初始化
function M.init()
    return true
end

-- 创建用户信息
function M.create_user_info(username, password, nickname)
    local now = os.time()
    return {
        username = username,
        password = password,
        nickname = nickname or username,
        avatar = "default.png",
        level = 1,
        exp = 0,
        vip_level = 0,
        gold = 1000,
        diamond = 100,
        register_time = now,
        last_login = now
    }
end

-- 创建新用户
function M.create_user(username, password, nickname, avatar)
    -- 检查用户名是否已存在
    local exists = M.get_user_by_username(username)
    if exists then
        return nil, "用户名已存在"
    end
    
    -- 创建用户信息
    local user = M.create_user_info(username, password, nickname)
    user.avatar = avatar or "default.png"
    
    -- 使用 db_client 创建用户
    return db_client.create_user(user)
end

-- 根据用户名获取用户
function M.get_user_by_username(username)
    local user = db_client.get_user_by_username(username)
    if user then
        -- 确保时间戳是数字
        user.register_time = tonumber(user.register_time) or os.time()
        user.last_login = tonumber(user.last_login) or os.time()
    end
    return user
end

-- 根据用户ID获取用户
function M.get_user_by_id(user_id)
    local users = call_db("get_user_by_id", user_id)
    return users and users[1]
end

-- 获取用户信息
function M.get_user(account)
    -- 先尝试从缓存获取
    local user = cache.get_user_info(account)
    if user then
        logger.debug("Get user from cache, account: %s", account)
        return user
    end

    -- 缓存未命中，从数据库获取
    logger.debug("Cache miss, getting user from DB, account: %s", account)
    local db = skynet.call(".db_proxy", "lua", "get_user", account)
    if not db then
        return nil
    end

    -- 写入缓存
    cache.set_user_info(account, db)
    logger.debug("User info cached, account: %s", account)
    return db
end

-- 更新用户信息
function M.update_user(user)
    -- 先更新数据库
    local ok = skynet.call(".db_proxy", "lua", "update_user", user)
    if not ok then
        return false
    end

    -- 清除缓存，强制下次重新加载
    cache.remove_user_info(user.account)
    logger.debug("User cache cleared after update, account: %s", user.account)
    return true
end

-- 添加用户会话
function M.add_user(client_id, user_info)
    -- 检查用户是否已经在线
    local old_client_id = session_by_username[user_info.username]
    if old_client_id then
        -- 踢掉旧的连接
        sessions[old_client_id] = nil
        logger.info("Kicked old session for user: %s", user_info.username)
    end
    
    -- 添加新会话
    sessions[client_id] = {
        user_info = user_info,
        login_time = os.time()
    }
    session_by_username[user_info.username] = client_id
    
    -- 更新最后登录时间
    user_info.last_login = os.time()
    M.update_user(user_info)
    
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
function M.get_user(client_id)
    return sessions[client_id]
end

-- 检查用户是否在线
function M.is_user_online(username)
    return session_by_username[username] ~= nil
end

-- 获取用户统计信息
function M.get_stats()
    -- 获取总用户数
    local total = call_db("get_total_users") or 0
    
    -- 获取在线用户数和列表
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
    
    -- 获取最近注册的用户
    local recent_users = call_db("get_recent_users") or {}
    
    return {
        total_users = total,
        online_users = online_count,
        recent_users = recent_users,
        online_list = online_users
    }
end

-- 获取或创建用户
function M.get_or_create_user(username, password)
    -- 先尝试获取用户
    local user = M.get_user_by_username(username)
    local is_new_user = false
    
    if not user then
        -- 用户不存在，创建新用户
        logger.debug("Creating new user for account: %s", username)
        user = M.create_user(username, password, username)
        if not user then
            return nil, "创建用户失败"
        end
        is_new_user = true
        logger.info("New user created: %s (ID: %d)", username, user.user_id)
    else
        -- 用户存在，验证密码
        if user.password ~= password then
            logger.error("Wrong password for user: %s", username)
            return nil, "密码错误"
        end
        logger.debug("User logged in: %s (ID: %d)", username, user.user_id)
    end
    
    return user, nil, is_new_user
end

return M 