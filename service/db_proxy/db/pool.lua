local skynet = require "skynet"
local logger = require "logger"
local mysql = require "mysql"
local database = require "database"

local M = {}

-- 连接池配置
local pool = {
    connections = {},
    size = 0,
    max_size = database.mysql.pool.max_connections,  -- 最大连接数
    min_size = database.mysql.pool.min_connections,  -- 最小连接数
    current = 0    -- 当前使用的连接索引
}

-- 创建新连接
local function create_connection()
    if not mysql.init(database.mysql) then
        return nil, "Failed to initialize MySQL"
    end
    return mysql
end

-- 获取连接
function M.get()
    -- 先从池中获取
    if pool.size > 0 then
        pool.current = (pool.current % pool.size) + 1
        return pool.connections[pool.current]
    end
    
    -- 创建新连接
    local conn, err = create_connection()

    if conn then
        pool.size = pool.size + 1
        pool.current = pool.size
        pool.connections[pool.size] = conn
        return conn
    else
        logger.error("Failed to create connection: %s", err)
    end
    
    return nil
end

-- 检查并维护连接池
function M.check()
    -- 检查现有连接
    for i = pool.size, 1, -1 do
        local conn = pool.connections[i]
        local ok = pcall(function()
            mysql.query("SELECT 1")
        end)
        if not ok then
            -- 移除失效连接
            table.remove(pool.connections, i)
            pool.size = pool.size - 1
            if pool.current >= i then
                pool.current = pool.current - 1
            end
        end
    end
    
    -- 补充连接到最小数量
    while pool.size < pool.min_size do
        local conn, err = create_connection()

        if conn then
            pool.size = pool.size + 1
            pool.connections[pool.size] = conn
        else
            logger.error("Failed to create connection: %s", err)
            break
        end
    end
    
    return pool.size > 0
end

-- 初始化连接池
function M.init()
    -- 创建初始连接
    for i = 1, pool.min_size do
        local conn, err = create_connection()
        if conn then
            pool.size = pool.size + 1
            pool.connections[pool.size] = conn
        else
            logger.error("Failed to create initial connection %d: %s", i, err)
            break
        end
    end
    
    -- 启动连接池维护任务
    skynet.fork(function()
        while true do
            M.check()
            skynet.sleep(database.mysql.pool.reconnect_interval * 100)
        end
    end)
    
    return pool.size > 0
end

-- 执行查询
function M.query(sql, ...)
    local conn = M.get()
    if not conn then
        return false, "No available connection"
    end
    
    -- 直接使用mysql模块的query方法
    local ok, res = pcall(mysql.query, sql)
    
    if not ok then
        -- 连接可能断开，尝试重新获取
        M.check()
        conn = M.get()
        if conn then
            ok, res = pcall(mysql.query, sql)
        end
    end
    
    if not ok then
        return false, res
    end
    
    -- 确保返回的是表格
    if type(res) ~= "table" then
        res = { affected_rows = 0 }
    end
    
    return res
end

return M 