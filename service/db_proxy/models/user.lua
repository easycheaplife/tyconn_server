local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local sql = require "db_proxy.sql.user"
local db_util = require "db_proxy.utils.db_util"
local utils = require "utils"

local M = {}

-- 记录SQL日志
local function log_sql(sql_str, ...)
    if ... then
        sql_str = string.format(sql_str, ...)
    end
    logger.debug("[SQL] %s", sql_str)
end

-- 创建用户
function M.create_user(user)
    logger.debug("Creating user: %s", table.concat({
        account = user.account,
        username = user.username
    }, ", "))
    
    -- 检查用户是否已存在
    local query = string.format(sql.GET_USER_BY_USERNAME, 
        mysql.escape(user.username))
    log_sql(query)
    
    local results = db_util.query(query)
    if results and #results > 0 then
        logger.error("Username already exists: %s", user.username)
        return false, "Username already exists"
    end
    
    local current_time = os.time()
    
    -- 插入新用户
    query = string.format(sql.CREATE_USER,
        mysql.escape(user.account),
        mysql.escape(user.username),
        user.level or 1,
        user.exp or 0,
        user.vip_level or 0,
        current_time,  -- create_time
        current_time   -- last_login_time
    )
    log_sql(query)
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create user")
        return false, "Database error"
    end
    
    -- 获取新创建的用户信息
    query = string.format(sql.GET_USER_BY_USERNAME, 
        mysql.escape(user.username))
    log_sql(query)
    
    results = db_util.query(query)
    if not results or #results == 0 then
        logger.error("Failed to get created user")
        return false, "Database error"
    end
    
    return true, results[1], true
end

-- 获取用户信息
function M.get_user(account)
    logger.debug("Getting user with account: %s", account)
    
    local query = string.format(sql.GET_USER_BY_ACCOUNT, mysql.escape(account))
    log_sql(query)
    local results = db_util.query(query)
    if not results or #results == 0 then
        logger.info("Failed to get user for account: %s", account)
        return nil
    end
    return results[1]
end

-- 获取用户信息
function M.get_user_info(user_id)
    local query = string.format(sql.GET_USER_BY_ID, user_id)
    log_sql(query)
    local results = db_util.query(query)
    return results[1]
end

-- 更新用户信息
function M.update_user(user)
    if not user or not user.account then
        return false, "无效的用户信息"
    end
    
    local query = string.format(sql.UPDATE_USER,
        user.level,
        user.exp,
        user.vip_level,
        os.time(),  -- 更新 last_login_time
        mysql.escape(user.account)
    )
    log_sql(query)
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to update user: %s", err)
        return false, "Database error"
    end
    
    return ok
end

-- 获取用户总数
function M.get_total_users()
    local query = string.format(sql.GET_TOTAL_USERS)
    local ok, results = pcall(db_util.query, query)
    if not ok then
        logger.error("Failed to get total users: %s", results)
        return 0
    end
    return results[1] and results[1].count or 0
end

-- 获取最近用户
function M.get_recent_users()
    local query = string.format(sql.GET_RECENT_USERS)
    local ok, results = pcall(db_util.query, query)
    if not ok then
        logger.error("Failed to get recent users: %s", results)
        return {}
    end
    return results or {}
end

-- 获取在线用户数
function M.get_online_users()
    local query = string.format(sql.GET_ONLINE_USERS, os.time() - 300, os.time())
    
    local ok, results = pcall(db_util.query, query)
    if not ok then
        logger.error("Failed to get online users: %s", results)
        return 0
    end
    return results[1] and results[1].count or 0
end

return M 