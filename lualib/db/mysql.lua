local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local logger = require "logger"
local config = require "config.mysql"

local M = {}
local db

-- 获取数据库连接
local function get_db()
    if not db then
        logger.error("MySQL connection lost, trying to reconnect...")
        if not M.init() then
            logger.error("Failed to reconnect to MySQL")
            return nil
        end
    end
    return db
end

-- 检查并创建数据库
local function ensure_database(conn, db_name)
    -- 检查数据库是否存在
    local sql = string.format("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '%s'", db_name)
    local res = conn:query(sql)
    if not res then
        return false, "Failed to check database existence"
    end
    
    if #res == 0 then
        logger.info("Database '%s' not found, creating...", db_name)
        -- 创建数据库
        sql = string.format("CREATE DATABASE IF NOT EXISTS %s DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", db_name)
        res = conn:query(sql)
        if not res then
            return false, "Failed to create database"
        end
        logger.info("Database '%s' created successfully", db_name)
    else
        logger.info("Database '%s' already exists", db_name)
    end
    
    -- 切换到指定数据库
    res = conn:query("USE " .. db_name)
    if not res then
        return false, "Failed to switch to database"
    end
    
    return true
end

-- 开始事务
function M.begin()
    local connection = get_db()
    if not connection then
        return false
    end
    return connection:query("START TRANSACTION")
end

-- 提交事务
function M.commit()
    local connection = get_db()
    if not connection then
        return false
    end
    return connection:query("COMMIT")
end

-- 回滚事务
function M.rollback()
    local connection = get_db()
    if not connection then
        return false
    end
    return connection:query("ROLLBACK")
end

-- 执行查询
function M.query(sql, ...)
    local connection = get_db()
    if not connection then
        return nil
    end
    
    -- 格式化SQL
    if ... then
        -- 转义参数，防止SQL注入
        local args = {...}
        for i, arg in ipairs(args) do
            if type(arg) == "string" then
                -- 使用简单的转义方法，不依赖连接对象
                arg = string.gsub(arg, "(['\"\\\n\r])", "\\%1")
                args[i] = arg
            end
        end
        sql = string.format(sql, table.unpack(args))
    end
    
    local ok, res = pcall(connection.query, connection, sql)
    if not ok then
        logger.error("Query failed: %s\nSQL: %s", res, sql)
        -- 检查是否是连接错误
        if type(res) == "string" and (
            string.find(res, "MySQL server has gone away") or
            string.find(res, "Lost connection") or
            string.find(res, "Connection reset by peer")
        ) then
            logger.info("Connection lost, clearing connection and retrying...")
            db = nil
            return M.query(sql)
        end
        return nil
    end
    
    return res
end

-- 初始化数据库连接
function M.init()
    -- 从配置文件加载连接配置
    local conn_config = config.connection
    if not conn_config then
        logger.error("MySQL connection config not found")
        return false
    end
    
    -- 先建立初始连接
    local ok, result = pcall(mysql.connect, conn_config)
    if not ok then
        logger.error("Failed to connect to MySQL: %s", result)
        return false
    end
    
    local conn = result
    if not conn then
        logger.error("Connection object is nil")
        return false
    end
    
    -- 创建并切换到指定数据库
    ok, result = ensure_database(conn, config.database)
    if not ok then
        logger.error("Failed to ensure database: %s", result)
        pcall(conn.close, conn)
        return false
    end
    
    db = conn
    logger.info("MySQL connected successfully")
    return true
end

return M 