local skynet = require "skynet"
local db = require "simpledb"
local pb = require "pb"
local logger = require "logger"
local utils = require "utils"

local M = {}
local db_id  -- 保存数据库连接ID

-- 初始化数据库连接
function M.init()
    db_id = db.connect({})
    return db_id ~= nil
end

-- 创建用户信息
function M.create_user_info(username, password, nickname)
    return {
        user_id = nil,              -- 将由 create_user 设置
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
    local exists = db.get(db_id, "user:" .. username)
    logger.debug("Creating user - username: %s, exists: %s", username, exists and "true" or "false")
    
    if exists then
        return nil, "用户名已存在"
    end
    
    -- 创建用户信息
    local user = M.create_user_info(username, password, nickname)
    user.user_id = db.incr(db_id, "next_user_id")
    user.avatar = avatar or "default.png"
    
    -- 保存用户数据
    db.set(db_id, "user:" .. username, user)
    db.set(db_id, "user_id:" .. user.user_id, user)
    
    logger.debug("User created: %s", utils.table_to_string(user))
    return user
end

-- 根据用户名获取用户
function M.get_user_by_username(username)
    local user = db.get(db_id, "user:" .. username)
    logger.debug("get_user_by_username - username: %s, result: %s", 
        username, 
        user and utils.table_to_string(user) or "nil"
    )
    return user
end

-- 根据用户ID获取用户
function M.get_user_by_id(user_id)
    return db.get(db_id, "user_id:" .. user_id)
end

-- 用户会话管理
local sessions = {}  -- 改名为更合适的名字
local session_by_username = {}  -- 用户名到会话的映射

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
    -- 使用 db.dump 来获取数据库内容
    local db_content = db.dump(db_id)
    if not db_content then
        return {
            total_users = 0,
            online_users = 0,
            recent_users = {}
        }
    end
    
    -- 统计在线用户
    local online_count = 0
    for _ in pairs(sessions) do
        online_count = online_count + 1
    end
    
    -- 获取所有用户
    local all_users = {}
    local keys = db.keys(db_id, "^user:")
    for _, key in ipairs(keys) do
        local user = db.get(db_id, key)
        if user then
            table.insert(all_users, user)
        end
    end
    
    -- 按注册时间排序，获取最近注册的用户（最多10个）
    table.sort(all_users, function(a, b)
        return (a.register_time or 0) > (b.register_time or 0)
    end)
    
    local recent_users = {}
    for i = 1, math.min(10, #all_users) do
        table.insert(recent_users, all_users[i])
    end
    
    -- 添加在线用户详细信息
    local online_users = {}
    for client_id, session in pairs(sessions) do
        table.insert(online_users, {
            username = session.user_info.username,
            client_id = client_id,
            login_time = session.login_time
        })
    end
    
    -- 按登录时间排序
    table.sort(online_users, function(a, b)
        return a.login_time > b.login_time
    end)
    
    return {
        total_users = #all_users,
        online_users = #online_users,
        recent_users = recent_users,
        online_list = online_users  -- 添加在线用户列表
    }
end

-- 更新用户信息
function M.update_user(user)
    if not user or not user.username then
        return false
    end
    
    -- 更新用户数据
    db.set(db_id, "user:" .. user.username, user)
    db.set(db_id, "user_id:" .. user.user_id, user)
    return true
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
    else
        -- 用户存在，验证密码
        if user.password ~= password then
            logger.error("Wrong password for user: %s", username)
            return nil, "密码错误"
        end
    end
    
    return user, nil, is_new_user  -- 返回用户信息、错误信息、是否新用户
end

return M 