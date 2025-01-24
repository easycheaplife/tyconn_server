local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"

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
    mysql.query("START TRANSACTION")
    
    local ok, result, err = pcall(func)
    if not ok or not result then
        M.log_sql("ROLLBACK")
        mysql.query("ROLLBACK")
        return false, ok and err or result
    end
    
    M.log_sql("COMMIT")
    mysql.query("COMMIT")
    return result, err
end

-- 执行SQL查询
function M.query(sql, ...)
    M.log_sql(sql, ...)
    return mysql.query(sql, ...)
end

-- 转义SQL字符串
function M.escape(str)
    if not str then
        return "NULL"
    end
    return mysql.quote_sql_str(str)
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