local skynet = require "skynet"
local logger = require "logger"
local redis = require "redis"
local database = require "database"
local cjson = require "cjson"

local M = {}

-- 缓存前缀
local PREFIX = database.redis.prefix

-- 过期时间(秒)
local EXPIRE = database.redis.expire

local function make_key(prefix, id)
    return prefix .. tostring(id)
end

-- Token相关
function M.get_token(account)
    local key = make_key(PREFIX.token, account)
    return redis.get(key)
end

function M.set_token(account, token)
    local key = make_key(PREFIX.token, account)
    local ok = redis.set(key, token)
    if ok then
        redis.expire(key, EXPIRE.token)
    end
    return ok
end

function M.remove_token(account)
    local key = make_key(PREFIX.token, account)
    return redis.del(key) > 0
end

-- 用户相关
function M.get_user_info(account)
    local key = make_key(PREFIX.user, account)
    local data = redis.get(key)
    if data then
        logger.debug("Got user cache - Key: %s, Data: %s", key, data)
        local ok, user = pcall(cjson.decode, data)
        if ok then
            return user
        else
            logger.error("Failed to decode user cache: %s", user)
        end
    end
    return nil
end

function M.set_user_info(account, user)
    local key = make_key(PREFIX.user, account)
    local data = cjson.encode(user)
    logger.debug("Setting user cache - Key: %s, Data: %s", key, data)
    
    local ok = redis.set(key, data)
    if ok then
        -- 设置过期时间
        ok = redis.expire(key, EXPIRE.user)
        logger.debug("Set cache expire time for user: %s, ok: %s", account, tostring(ok))
    else
        logger.error("Failed to set user cache for: %s", account)
    end
    return ok
end

function M.remove_user_info(account)
    local key = make_key(PREFIX.user, account)
    return redis.del(key) > 0
end

-- 卡牌相关
function M.get_user_cards(user_id)
    local key = make_key(PREFIX.user_cards, user_id)
    local data = redis.get(key)
    if data then
        return cjson.decode(data)
    end
    return nil
end

function M.set_user_cards(user_id, cards)
    local key = make_key(PREFIX.user_cards, user_id)
    local data = cjson.encode(cards)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.user_cards)
    end
    return ok
end

function M.remove_user_cards(user_id)
    local key = make_key(PREFIX.user_cards, user_id)
    return redis.del(key) > 0
end

return M