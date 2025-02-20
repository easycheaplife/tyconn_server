local skynet = require "skynet"
local cluster = require "skynet.cluster"
local db_client = require "game.db_client"
local cache = require "game.cache"
local logger = require "logger"
local utils = require "utils"
local user_model = require "models.user_model"

local M = {}

-- 调用数据库代理
local function call_db(...)
    return cluster.call("db_proxy", "@db_proxy", ...)
end

-- 从数据库获取用户
function M.get_user(account)
    return db_client.get_user(account)
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

-- 创建用户
function M.create_user(user_data)
    -- 验证数据
    local ok, err = user_model.validate(user_data)
    if not ok then
        return false, err
    end

    -- 1. 写入数据库
    local success, created_user = db_client.create_user(user_data)
    if not success then
        logger.error("Failed to create user in database")
        return false, "数据库创建失败"
    end

    return true, created_user
end

-- 更新用户
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

-- 从缓存获取用户
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

-- 保存用户到缓存
function M.cache_user(user)
    if not user or not user.user_id then
        return false, "Invalid user info"
    end
    logger.debug("Caching user info: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))
    return cache.set_user_info(user.user_id, user)
end

-- 保存账号映射到缓存
function M.cache_user_by_account(user)
    if not user or not user.account or not user.user_id then
        return false, "Invalid user info"
    end
    logger.debug("Caching user info by account: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))
    return cache.set_account_mapping(user.account, user.user_id)
end

return M 