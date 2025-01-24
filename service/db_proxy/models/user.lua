local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local sql = require "db_proxy.sql.user"

local M = {}

-- 记录SQL日志
local function log_sql(sql_str, ...)
    if ... then
        sql_str = string.format(sql_str, ...)
    end
    logger.debug("[SQL] %s", sql_str)
end

-- 事务包装器
local function transaction(func)
    mysql.query("START TRANSACTION")
    log_sql("START TRANSACTION")
    
    local ok, result, err = pcall(func)
    if not ok or not result then
        mysql.query("ROLLBACK")
        log_sql("ROLLBACK")
        return false, ok and err or result
    end
    
    mysql.query("COMMIT")
    log_sql("COMMIT")
    return result, err
end

-- 创建用户
function M.create_user(user)
    logger.debug("Creating user: %s", table.concat({
        account = user.account,
        username = user.username,
        name = user.name
    }, ", "))
    
    return transaction(function()
        -- 检查用户是否已存在
        local query = string.format(sql.CHECK_USER_EXISTS, mysql.escape(user.username))
        log_sql(query)
        
        local ok, results = pcall(mysql.query, query)
        if not ok then
            logger.error("Failed to check user existence: %s", results)
            return false, "Database error"
        end
        
        if results[1] then
            logger.error("Username already exists: %s", user.username)
            return false, "Username already exists"
        end
        
        -- 插入用户数据
        query = string.format(sql.CREATE_USER,
            mysql.escape(user.account),
            mysql.escape(user.username),
            mysql.escape(user.name),
            user.gender,
            user.job,
            user.level,
            user.exp,
            user.create_time
        )
        log_sql(query)
        
        ok, results = pcall(mysql.query, query)
        if not ok then
            logger.error("Failed to insert user: %s", results)
            return false, "Database error"
        end
        
        -- 获取创建的用户信息
        query = string.format(sql.GET_USER_BY_ACCOUNT, mysql.escape(user.account))
        log_sql(query)
        
        ok, results = pcall(mysql.query, query)
        if not ok then
            logger.error("Failed to get created user: %s", results)
            return false, "Database error"
        end
        
        if not results[1] then
            logger.error("Created user not found: account=%s", user.account)
            return false, "Database error"
        end
        
        return true, results[1]
    end)
end

-- 获取用户信息
function M.get_user(account)
    logger.debug("Getting user with account: %s", account)
    
    local query = string.format(sql.GET_USER_BY_ACCOUNT, mysql.escape(account))
    log_sql(query)
    
    local ok, results = pcall(mysql.query, query)
    if not ok then
        logger.error("Failed to get user: %s", results)
        return {
            success = false,
            error = "Database error"
        }
    end
    
    return {
        success = true,
        user = results[1]  -- 如果用户不存在，这里会是 nil
    }
end

-- 更新用户信息
function M.update_user(user)
    if not user or not user.account then
        return false, "无效的用户信息"
    end
    
    local query = string.format(sql.UPDATE_USER,
        mysql.escape(user.name),
        user.level,
        user.exp,
        user.job,
        user.gender,
        os.time(),
        mysql.escape(user.account)
    )
    log_sql(query)
    
    local ok, results = pcall(mysql.query, query)
    if not ok then
        logger.error("Failed to update user: %s", results)
        return false, "Database error"
    end
    
    return true
end

return M 