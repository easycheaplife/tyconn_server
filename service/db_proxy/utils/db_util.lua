local skynet = require "skynet"
local logger = require "logger"
local mysql = require "mysql"
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

-- 转义 SQL 字符串
function M.escape_string(str)
    if not str then
        return ""
    end
    
    -- 基本的转义规则
    local escaped = string.gsub(str, "'", "''")  -- 转义单引号
    escaped = string.gsub(escaped, "\\", "\\\\") -- 转义反斜杠
    
    return escaped
end

-- 开始事务
function M.start_transaction()
    return M.query("START TRANSACTION")
end

-- 提交事务
function M.commit()
    return M.query("COMMIT")
end

-- 回滚事务
function M.rollback()
    return M.query("ROLLBACK")
end

-- 在事务中执行操作
function M.transaction(func)
    -- 开始事务
    local ok, err = M.start_transaction()
    if not ok then
        logger.error("Failed to start transaction: %s", err)
        return false, "Failed to start transaction: " .. tostring(err)
    end
    
    -- 执行操作
    local success, result, extra = pcall(func)
    
    -- 检查执行结果
    if not success then
        -- 操作执行失败，回滚事务
        logger.error("Transaction operation failed: %s", tostring(result))
        local rollback_ok = M.rollback()
        if not rollback_ok then
            logger.error("Failed to rollback transaction")
        end
        return false, "Operation failed: " .. tostring(result)
    elseif result == false then
        -- 操作返回false，回滚事务
        logger.error("Transaction operation returned false: %s", tostring(extra))
        local rollback_ok = M.rollback()
        if not rollback_ok then
            logger.error("Failed to rollback transaction")
        end
        return false, extra
    else
        -- 操作成功，提交事务
        local commit_ok, commit_err = M.commit()
        if not commit_ok then
            logger.error("Failed to commit transaction: %s", commit_err)
            -- 尝试回滚
            local rollback_ok = M.rollback()
            if not rollback_ok then
                logger.error("Failed to rollback transaction after commit failure")
            end
            return false, "Failed to commit transaction: " .. tostring(commit_err)
        end
        
        -- 返回操作结果
        return result, extra
    end
end

return M 