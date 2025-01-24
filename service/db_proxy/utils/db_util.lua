local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local const = require "db_proxy.const"

local M = {}

-- 连接池状态
local pool_status = {
    last_check = 0,
    reconnect_count = 0
}

-- 记录SQL日志
function M.log_sql(sql_str, ...)
    if ... then
        sql_str = string.format(sql_str, ...)
    end
    logger.debug("[SQL] %s", sql_str)
end

-- 检查连接状态
local function check_connection()
    local now = skynet.now()
    if now - pool_status.last_check < const.DB.RECONNECT_INTERVAL then
        return true
    end
    
    pool_status.last_check = now
    
    -- 执行ping查询检查连接
    local ok = pcall(mysql.query, "SELECT 1")
    if ok then
        pool_status.reconnect_count = 0
        return true
    end
    
    -- 尝试重连
    if pool_status.reconnect_count >= const.DB.MAX_RECONNECT_ATTEMPTS then
        logger.error("Max reconnection attempts reached")
        return false
    end
    
    pool_status.reconnect_count = pool_status.reconnect_count + 1
    logger.info("Attempting to reconnect to database (attempt %d/%d)",
        pool_status.reconnect_count, const.DB.MAX_RECONNECT_ATTEMPTS)
    
    return M.init()
end

-- 事务包装器
function M.transaction(func)
    M.log_sql("START TRANSACTION")
    local ok, err = pcall(mysql.query, "START TRANSACTION")
    if not ok then
        logger.error("Failed to start transaction: %s", err)
        return false, "Failed to start transaction"
    end
    
    local ok, result, err = pcall(func)
    logger.debug("Transaction function result - OK: %s, Result: %s, Error: %s", 
        tostring(ok), tostring(result), tostring(err))
    
    if not ok or not result then
        local error_msg = ok and err or result
        logger.error("Transaction failed - Error: %s", error_msg)
        M.log_sql("ROLLBACK")
        pcall(mysql.query, "ROLLBACK")
        return false, ok and err or result
    end
    
    M.log_sql("COMMIT")
    ok, err = pcall(mysql.query, "COMMIT")
    if not ok then
        logger.error("Failed to commit transaction: %s", err)
        pcall(mysql.query, "ROLLBACK")
        return false, "Failed to commit transaction"
    end
    return result, err
end

-- 执行SQL查询
function M.query(sql, ...)
    if not check_connection() then
        return false, "Database connection lost"
    end

    M.log_sql(sql, ...)
    local ok, results = pcall(mysql.query, sql, ...)
    if not ok then
        local error_msg = tostring(results)
        if error_msg:match("MySQL server has gone away") then
            logger.error("Lost connection to MySQL server, trying to reconnect...")
            if M.init() then
                -- 重试一次
                ok, results = pcall(mysql.query, sql, ...)
            end
        end
        if not ok then
            logger.error("SQL query failed: %s, SQL: %s", error_msg, sql)
            return false, error_msg
        end
    end
    if type(results) ~= "table" then
        logger.error("Unexpected query result type: %s, SQL: %s", type(results), sql)
        return false, "Invalid query result"
    end
    return results
end

-- 转义SQL字符串
function M.escape(str)
    if not str then
        return "NULL"
    end
    return mysql.escape(str)
end

-- 初始化数据库连接
function M.init()
    if not mysql.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    return true
end

return M 