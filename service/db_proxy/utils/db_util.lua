local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local pool = require "db_proxy.db.pool"
local database = require "database"

local M = {}

-- 记录SQL日志
function M.log_sql(sql)
    logger.debug("[SQL] %s", sql)
end

-- 执行SQL查询
function M.query(sql, ...)
    local query = sql
    -- 如果有参数，先格式化SQL
    if ... then
        query = string.format(sql, ...)
    end

    M.log_sql(query)
    
    -- 添加重试逻辑
    local retries = 0
    while retries < database.mysql.query.max_retries do
        local results, err = pool.query(query)
        if results then
            return results
        end
        
        logger.error("Query failed (attempt %d/%d): %s, SQL: %s", 
            retries + 1, 
            database.mysql.query.max_retries,
            err, 
            query)
            
        retries = retries + 1
        if retries < database.mysql.query.max_retries then
            skynet.sleep(database.mysql.query.retry_delay * 100)
        end
    end
    
    return false, "Max retries exceeded"
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

-- 执行SQL模板
function M.execute(template, params)
    if not template or not template.sql then
        return false, "Invalid SQL template"
    end

    -- 收集参数值
    local values = {}
    for _, param_name in ipairs(template.params) do
        local value = params[param_name]
        if value == nil then
            logger.error("Missing parameter: %s", param_name)
            return false, "Missing parameter"
        end
        
        -- 如果是字符串，进行转义
        if type(value) == "string" then
            value = M.escape(value)
        end
        
        table.insert(values, value)
    end

    -- 格式化SQL
    local sql = string.format(template.sql, table.unpack(values))
    return M.query(sql)
end

return M 