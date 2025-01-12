local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local mysql = require "db.mysql"
local sql = require "db.sql.user"

local M = {}

-- 用户会话管理
local sessions = {}  -- client_id -> session
local session_by_username = {}  -- username -> client_id

-- 初始化
function M.init()
    -- 初始化MySQL连接
    if not mysql.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    
    -- 创建用户表
    local res = mysql.query(sql.create_table)
    if not res then
        logger.error("Failed to create users table")
        return false
    end
    
    logger.info("User model initialized successfully")
    return true
end

-- 创建用户信息
function M.create_user_info(username, password, nickname)
    return {
        username = username,
        password = password,
        nickname = nickname or username,
        level = 1,
        exp = 0,
        vip_level = 0,
        gold = 1000,
        diamond = 100,
        avatar = "default.png",
        register_time = os.time(),
        last_login = os.time()
    }
end

-- 创建新用户
function M.create_user(username, password, nickname, avatar)
    -- 检查用户名是否已存在
    local exists = M.get_user_by_username(username)
    if exists then
        return nil, "用户名已存在"
    end
    
    -- 开始事务
    if not mysql.begin() then
        logger.error("Failed to begin transaction")
        return nil, "系统错误"
    end
    
    -- 创建用户信息
    local user = M.create_user_info(username, password, nickname)
    user.avatar = avatar or "default.png"
    
    -- 插入用户数据
    local res = mysql.query(sql.create_user,
        user.username,
        user.password,
        user.nickname,
        user.avatar,
        user.register_time,
        user.last_login
    )
    
    if not res or not res.insert_id then
        mysql.rollback()
        logger.error("Failed to create user in database: %s", username)
        return nil, "创建用户失败"
    end
    
    -- 获取创建的用户信息
    user = M.get_user_by_id(res.insert_id)
    if not user then
        mysql.rollback()
        logger.error("Failed to get created user: %s", username)
        return nil, "获取用户信息失败"
    end
    
    -- 提交事务
    if not mysql.commit() then
        mysql.rollback()
        logger.error("Failed to commit transaction")
        return nil, "系统错误"
    end
    
    logger.info("User created successfully: %s (ID: %d)", username, user.user_id)
    return user
end

-- 根据用户名获取用户
function M.get_user_by_username(username)
    local users = mysql.query(sql.get_by_username, username)
    return users and users[1]
end

-- 根据用户ID获取用户
function M.get_user_by_id(user_id)
    local users = mysql.query(sql.get_by_id, user_id)
    return users and users[1]
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
    local total = mysql.query("SELECT COUNT(*) as count FROM users")[1].count
    
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
    local recent_users = mysql.query([[
        SELECT * FROM users 
        ORDER BY register_time DESC 
        LIMIT 10
    ]])
    
    return {
        total_users = total,
        online_users = online_count,
        recent_users = recent_users or {},
        online_list = online_users
    }
end

-- 更新用户信息
function M.update_user(user)
    if not user or not user.user_id then
        return false
    end
    
    local res = mysql.query(sql.update_user,
        user.nickname,
        user.level,
        user.exp,
        user.vip_level,
        user.gold,
        user.diamond,
        user.avatar,
        user.last_login,
        user.user_id
    )
    
    return res and res.affected_rows > 0
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