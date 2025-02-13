local skynet = require "skynet"
local redis = require "skynet.db.redis"
local logger = require "logger"
local database = require "database"

local M = {}

-- Redis连接实例
local redis_client

-- 初始化Redis连接
local function init_redis()
    if redis_client then
        return true
    end

    local ok, db = pcall(redis.connect, {
        host = database.redis.host,
        port = database.redis.port,
        db = database.redis.db,
        auth = database.redis.auth
    })

    if not ok then
        logger.error("Failed to connect to Redis: %s", db)
        return false
    end

    redis_client = db
    return true
end

-- 获取Redis连接
local function get_redis()
    if not init_redis() then
        return nil
    end
    return redis_client
end

-- 基础操作封装
function M.get(key)
    local client = get_redis()
    if not client then
        return nil
    end
    return client:get(key)
end

function M.set(key, value)
    local client = get_redis()
    if not client then
        return false
    end
    return client:set(key, value)
end

function M.del(key)
    local client = get_redis()
    if not client then
        return 0
    end
    return client:del(key)
end

function M.expire(key, seconds)
    local client = get_redis()
    if not client then
        return false
    end
    return client:expire(key, seconds)
end

function M.exists(key)
    local client = get_redis()
    if not client then
        return false
    end
    return client:exists(key) == 1
end

-- 批量操作
function M.mget(keys)
    local client = get_redis()
    if not client then
        return nil
    end
    return client:mget(table.unpack(keys))
end

function M.mset(kvs)
    local client = get_redis()
    if not client then
        return false
    end
    return client:mset(kvs)
end

-- 事务操作
function M.multi()
    local client = get_redis()
    if not client then
        return false
    end
    return client:multi()
end

function M.exec()
    local client = get_redis()
    if not client then
        return false
    end
    return client:exec()
end

return M