local skynet = require "skynet"
local logger = require "logger"
local redis = require "skynet.db.redis"
local cjson = require "cjson"

local M = {}

-- 加载Redis配置
local redis_conf = require("database").redis

local redis_client

-- 初始化Redis连接
local function init_redis()
    if redis_client then
        return true
    end

    local ok, db = pcall(redis.connect, {
        host = redis_conf.host,
        port = redis_conf.port,
        db = redis_conf.db,
        auth = redis_conf.auth
    })

    if not ok then
        logger.error("Failed to connect to Redis: %s", db)
        return false
    end

    redis_client = db
    return true
end

-- 生成缓存key
local function make_key(prefix, id)
    local key_prefix = redis_conf.prefix[prefix] or prefix
    return string.format("%s:%s", key_prefix, tostring(id))
end

-- 设置缓存
local function set_cache(prefix, id, value, expire)
    if not init_redis() then
        return false
    end

    local key = make_key(prefix, id)
    local data = cjson.encode(value)
    
    local ok
    if expire then
        ok = redis_client:setex(key, expire, data)
    else
        ok = redis_client:set(key, data)
    end

    if not ok then
        logger.error("Failed to set cache: %s", key)
        return false
    end
    return true
end

-- 获取缓存
local function get_cache(prefix, id)
    if not init_redis() then
        return nil
    end

    local key = make_key(prefix, id)
    local data = redis_client:get(key)
    if not data then
        return nil
    end

    local ok, value = pcall(cjson.decode, data)
    if not ok then
        logger.error("Failed to decode cache data: %s", data)
        return nil
    end
    return value
end

-- 删除缓存
local function del_cache(prefix, id)
    if not init_redis() then
        return false
    end

    local key = make_key(prefix, id)
    local ok = redis_client:del(key)
    if not ok then
        logger.error("Failed to delete cache: %s", key)
        return false
    end
    return true
end

-- 用户卡牌缓存接口
function M.set_user_cards(user_id, cards)
    return set_cache("card", user_id, cards, redis_conf.expire.card)
end

function M.get_user_cards(user_id)
    return get_cache("card", user_id)
end

function M.remove_user_cards(user_id)
    return del_cache("card", user_id)
end

-- 用户信息缓存接口
function M.set_user_info(account, user)
    return set_cache("user", account, user, redis_conf.expire.user)
end

function M.get_user_info(account)
    return get_cache("user", account)
end

function M.remove_user_info(account)
    return del_cache("user", account)
end

-- Token缓存接口
function M.set_token(account, token)
    return set_cache("token", account, token, redis_conf.expire.token)
end

function M.get_token(account)
    return get_cache("token", account)
end

function M.remove_token(account)
    return del_cache("token", account)
end

return M 