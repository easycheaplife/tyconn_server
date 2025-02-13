local skynet = require "skynet"
local logger = require "logger"
local redis = require "redis"

local M = {}

-- 缓存前缀
local PREFIX = {
    TOKEN = "token:",
    USER = "user:",
    CARD = "card:",
    USER_CARDS = "user_cards:"
}

-- 过期时间(秒)
local EXPIRE = {
    TOKEN = 7200,    -- token缓存2小时
    USER = 3600,     -- 用户信息缓存1小时
    CARD = 1800,     -- 卡牌信息缓存30分钟
    USER_CARDS = 1800  -- 用户卡组缓存30分钟
}

local function make_key(prefix, id)
    return prefix .. tostring(id)
end

-- Token相关
function M.get_token(account)
    local key = make_key(PREFIX.TOKEN, account)
    return redis.get(key)
end

function M.set_token(account, token)
    local key = make_key(PREFIX.TOKEN, account)
    local ok = redis.set(key, token)
    if ok then
        redis.expire(key, EXPIRE.TOKEN)
    end
    return ok
end

function M.remove_token(account)
    local key = make_key(PREFIX.TOKEN, account)
    return redis.del(key) > 0
end

-- 用户相关
function M.get_user_info(account)
    local key = make_key(PREFIX.USER, account)
    local data = redis.get(key)
    if data then
        return skynet.unpack(data)
    end
    return nil
end

function M.set_user_info(account, user)
    local key = make_key(PREFIX.USER, account)
    local data = skynet.pack(user)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.USER)
    end
    return ok
end

function M.remove_user_info(account)
    local key = make_key(PREFIX.USER, account)
    return redis.del(key) > 0
end

-- 卡牌相关
function M.get_user_cards(user_id)
    local key = make_key(PREFIX.USER_CARDS, user_id)
    local data = redis.get(key)
    if data then
        return skynet.unpack(data)
    end
    return nil
end

function M.set_user_cards(user_id, cards)
    local key = make_key(PREFIX.USER_CARDS, user_id)
    local data = skynet.pack(cards)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.USER_CARDS)
    end
    return ok
end

function M.remove_user_cards(user_id)
    local key = make_key(PREFIX.USER_CARDS, user_id)
    return redis.del(key) > 0
end

return M