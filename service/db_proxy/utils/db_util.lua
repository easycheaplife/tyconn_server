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