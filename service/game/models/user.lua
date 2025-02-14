local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local utils = require "utils"
local db_client = require "game.db_client"
local cache = require "game.cache"

local M = {}

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
    -- 1. 从缓存获取
    local user = cache.get_user_info(account)
    if user then
        logger.debug("Get user from cache: %s", account)
        return user
    end

    -- 2. 从数据库获取
    local db_user = db_client.get_user(account)
    if not db_user then
        logger.debug("User not found: %s", account)
        return nil
    end

    -- 3. 写入缓存
    cache.set_user_info(account, db_user)
    logger.debug("User info cached: %s", account)

    return db_user
end

-- 更新用户信息
function M.update_user(user)
    -- 1. 更新数据库
    local ok = db_client.update_user(user)
    if not ok then
        return false
    end

    -- 2. 清除缓存
    cache.remove_user_info(user.account)
    logger.debug("User cache cleared: %s", user.account)

    return true
end

-- 获取用户统计信息
function M.get_stats()
    -- 获取总用户数和最近注册用户
    local total = db_client.get_total_users() or 0
    local recent_users = db_client.get_recent_users() or {}
    
    return {
        total_users = total,
        recent_users = recent_users
    }
end

-- 创建用户
function M.create_user(user_data)
    -- 检查必要字段
    if not user_data.account then
        logger.error("Missing account field in user data")
        return false, "Invalid user data"
    end

    -- 1. 写入数据库
    local success, user, is_new = db_client.create_user(user_data)
    if not success then
        logger.error("Failed to create user: %s", user)
        return false, user
    end

    -- 确保返回的用户数据包含 account
    if not user.account then
        user.account = user_data.account
    end

    -- 2. 写入缓存
    cache.set_user_info(user.account, user)
    logger.debug("New user cached: %s", user.account)

    return true, user, is_new
end

-- 获取或创建用户
function M.get_or_create_user(account, username)
    -- 1. 尝试获取用户
    local user = M.get_user(account)
    if user then
        return user, nil, false
    end

    -- 2. 创建新用户
    logger.debug("Creating new user for account: %s", account)
    local user_data = {
        account = account,  -- 确保设置 account
        username = username,
        level = 1,
        exp = 0,
        vip_level = 0,
        create_time = os.time(),
        last_login = os.time()
    }

    local success, created_user, is_new = M.create_user(user_data)
    if not success then
        return nil, created_user -- created_user 此时是错误信息
    end

    logger.info("New user created: %s (ID: %d)", account, created_user.user_id)
    return created_user, nil, is_new
end

-- 从缓存获取用户信息
function M.get_user_from_cache(account)
    local user = cache.get_user_info(account)
    if user then
        logger.debug("Got user from cache: %s", account)
        return { user = user }
    end
    return nil
end

-- 缓存用户信息
function M.cache_user(user)
    if not user or not user.account then
        logger.error("Failed to cache user: invalid user data")
        return false
    end
    
    logger.debug("Caching user info: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))

    local ok = cache.set_user_info(user.account, user)
    if ok then
        logger.debug("Successfully cached user info for: %s", user.account)
    else
        logger.error("Failed to cache user info for: %s", user.account)
    end
    return ok
end

return M 