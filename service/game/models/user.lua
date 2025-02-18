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
    logger.debug("Getting user info for account: %s", account)
    if not account then
        return nil
    end

    -- 1. 从缓存获取
    local user = M.get_user_from_cache(account)
    if user then
        logger.debug("Got user from cache: %s, user_id: %s", account, user.user_id)
        return user
    end

    -- 2. 从数据库获取
    local result = db_client.get_user(account)
    if not result then
        logger.error("Failed to get user from db: %s", account)
        return nil
    end

    logger.debug("Got user from db: %s, user_id: %s", account, result.user_id)
    -- 3. 写入缓存
    M.cache_user_by_id(result)
    M.cache_user_by_account(result)  -- 同时缓存 account 到 user_id 的映射

    return result
end

-- 更新用户信息
function M.update_user(user)
    if not user or not user.user_id then
        logger.error("Invalid user data for update")
        return false
    end

    -- 1. 更新数据库
    local ok = db_client.update_user(user)
    if not ok then
        return false
    end

    -- 2. 清除缓存
    cache.remove_user_info(user.user_id)
    cache.remove_account_mapping(user.account)
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
    M.cache_user_by_id(user)
    M.cache_user_by_account(user)
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
    logger.debug("Getting user from cache: %s", account)
    -- 先获取user_id
    local user_id = cache.get_user_id_by_account(account)
    if not user_id then
        return nil
    end
    -- 再获取用户信息
    local user = cache.get_user_info(user_id)
    if user then
        logger.debug("Got user from cache: %s", account)
        return user
    end
    return nil
end

-- 缓存用户信息(通过user_id)
function M.cache_user_by_id(user)
    if not user or not user.user_id then
        logger.error("Failed to cache user: invalid user data")
        return false
    end
    
    logger.debug("Caching user info by ID: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))

    return cache.set_user_info(user.user_id, user)
end

-- 缓存用户信息(通过account)
function M.cache_user_by_account(user)
    if not user or not user.account then
        logger.error("Failed to cache user: invalid user data")
        return false
    end
    
    logger.debug("Caching user info by account: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))

    return cache.set_account_mapping(user.account, user.user_id)
end

-- 增加经验
function M.add_exp(user_id, exp)
    logger.debug("Adding exp to user %d: %d", user_id, exp)
    if not user_id or not exp or exp <= 0 then
        return false, "参数无效"
    end

    -- 从缓存获取用户信息
    local user_info = cache.get_user_info(user_id)
    if not user_info then
        return false, "用户不存在"
    end

    -- 确保经验值存在
    user_info.exp = (user_info.exp or 0) + exp
    
    -- 更新数据库和缓存
    local ok = db_client.update_user(user_info)
    if not ok then
        return false, "更新失败"
    end
    
    cache.set_user_info(user_id, user_info)
    return true
end

-- 增加金币
function M.add_gold(user_id, gold)
    logger.debug("Adding gold to user %d: %d", user_id, gold)
    if not user_id or not gold or gold <= 0 then
        return false, "参数无效"
    end

    local user_info = cache.get_user_info(user_id)
    if not user_info then
        return false, "用户不存在"
    end

    -- 确保金币值存在
    user_info.gold = (user_info.gold or 0) + gold
    
    -- 更新数据库和缓存
    local ok = db_client.update_user(user_info)
    if not ok then
        return false, "更新失败"
    end
    
    cache.set_user_info(user_id, user_info)
    return true
end

-- 将用户信息存入缓存
function M.cache_user(user_info)
    if not user_info or not user_info.user_id then
        return false, "Invalid user info"
    end
    
    logger.debug("Caching user info: %s", utils.table_to_string({
        account = user_info.account,
        user_id = user_info.user_id,
        username = user_info.username
    }))

    return cache.set_user_info(user_info.user_id, user_info)
end

return M 