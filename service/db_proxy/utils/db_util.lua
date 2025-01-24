local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local const = require "db_proxy.const"
local pool = require "db_proxy.db.pool"

local M = {}

-- 记录SQL日志
function M.log_sql(sql_str, ...)
    if ... then
        sql_str = string.format(sql_str, ...)
    end
    logger.debug("[SQL] %s", sql_str)
end

-- 事务包装器
function M.transaction(func)
    M.log_sql("START TRANSACTION")
    local ok, err = pool.query("START TRANSACTION")
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
        pool.query("ROLLBACK")
        return false, ok and err or result
    end
    
    M.log_sql("COMMIT")
    ok, err = pool.query("COMMIT")
    if not ok then
        logger.error("Failed to commit transaction: %s", err)
        pool.query("ROLLBACK")
        return false, "Failed to commit transaction"
    end
    return result, err
end

-- 执行SQL查询
function M.query(sql, ...)
    local query = sql
    -- 如果有参数，先格式化SQL
    if ... then
        query = string.format(sql, ...)
    end

    M.log_sql(query)
    local results, err = pool.query(query)
    if not results then
        logger.error("Query failed: %s, SQL: %s", err, query)
        return false, err
    end
    
    -- 确保返回的是表格
    if type(results) ~= "table" then
        results = { affected_rows = 0 }
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
    if not pool.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    return true
end

return M 