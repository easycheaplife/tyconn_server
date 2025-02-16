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
    logger.debug("Getting user cache - Account: %s", account)
    local key = make_key(PREFIX.user, account)
    logger.debug("Getting user cache - Key: %s", key)
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

-- 用户物品缓存key
local function get_user_items_key(account)
    return string.format("%s%s", PREFIX.user_items, account)
end

-- 获取用户物品缓存
function M.get_user_items(account)
    local key = get_user_items_key(account)
    local data = redis.get(key)
    if data then
        return cjson.decode(data)
    end
    return nil
end

-- 设置用户物品缓存
function M.set_user_items(account, items)
    if not account or not items then
        return false
    end
    
    local key = get_user_items_key(account)
    
    -- 确保 items 是数组
    if type(items) ~= "table" then
        items = {}
    end
    
    -- 序列化数据
    local ok, data = pcall(cjson.encode, items)
    if not ok then
        logger.error("Failed to encode items for user %s: %s", account, data)
        return false
    end
    
    -- 设置缓存
    ok = redis.set(key, data)
    if not ok then
        logger.error("Failed to set items cache for user %s", account)
        return false
    end
    
    -- 设置过期时间
    ok = redis.expire(key, EXPIRE.user_items)
    if not ok then
        logger.error("Failed to set expire time for user items %s", account)
        -- 继续执行，不影响缓存使用
    end
    
    return true
end

-- 删除用户物品缓存
function M.remove_user_items(account)
    local key = get_user_items_key(account)
    return redis.del(key) > 0
end

return M