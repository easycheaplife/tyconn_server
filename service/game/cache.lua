local skynet = require "skynet"
local logger = require "logger"
local redis = require "redis"
local database = require "database"
local cjson = require "cjson"
local utils = require "utils"

local M = {}

-- 缓存前缀
local PREFIX = database.redis.prefix

-- 过期时间(秒)
local EXPIRE = database.redis.expire

local function make_key(prefix, key)    
    if type(key) == "number" then
        return string.format("%s%d", prefix, key)  -- 使用 %d 格式化整数
    else
        return prefix .. tostring(key)
    end
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
function M.get_user_info(user_id)
    logger.debug("Getting user info by ID: %d", user_id)
    local cache_key = make_key(PREFIX.user_info, user_id)
    local data = redis.get(cache_key)
    if data then
        local ok, user = pcall(cjson.decode, data)
        if ok then
            logger.debug("Got user from cache: %s", utils.table_to_string(user))
            return user
        end
        logger.error("Failed to decode user data: %s", data)
    end
    return nil
end

function M.set_user_info(user_id, user)
    local key = make_key(PREFIX.user_info, user_id)
    local data = cjson.encode(user)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.user)
    end
    return ok
end

function M.remove_user_info(user_id)
    local key = make_key(PREFIX.user_info, user_id)
    return redis.del(key) > 0
end

-- 通过account获取user_id
function M.get_user_id_by_account(account)
    logger.debug("Getting user ID by account: %s", account)
    local key = make_key(PREFIX.user_account, account)
    local user_id = redis.get(key)
    if user_id then
        return tonumber(user_id)
    end
    return nil
end

-- 缓存account到user_id的映射
function M.set_account_mapping(account, user_id)
    logger.debug("Setting account mapping: %s -> %d", account, user_id)
    local key = make_key(PREFIX.user_account, account)
    local ok = redis.set(key, tostring(user_id))
    if ok then
        redis.expire(key, EXPIRE.user)
    end
    return ok
end

-- 删除account映射
function M.remove_account_mapping(account)
    local key = make_key(PREFIX.user_account, account)
    return redis.del(key) > 0
end

-- 卡牌相关
function M.get_user_cards(user_id)
    logger.debug("Getting user cards for user %d", user_id)
    local key = make_key(PREFIX.user_cards, user_id)
    logger.debug("Cache key: %s", key)
    local data = redis.get(key)
    if data then
        logger.debug("Got cards from cache: %s", data)
        return cjson.decode(data)
    end
    return nil
end

function M.set_user_cards(user_id, cards)
    logger.debug("Setting user cards for user %d: %s", user_id, utils.table_to_string(cards))
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
local function get_user_items_key(user_id)
    return make_key(PREFIX.user_items, user_id)
end

-- 获取用户物品缓存
function M.get_user_items(user_id)
    if not user_id then
        logger.error("Invalid user_id for getting items")
        return nil
    end

    local key = get_user_items_key(user_id)
    local data = redis.get(key)
    if data then
        local ok, items = pcall(cjson.decode, data)
        if ok then
            return items
        end
        logger.error("Failed to decode items data: %s", data)
    end
    return nil
end

-- 设置用户物品缓存
function M.set_user_items(user_id, items)
    if not user_id or not items then
        logger.error("Invalid parameters for setting items cache")
        return false
    end
    
    local key = get_user_items_key(user_id)
    
    -- 确保 items 是数组
    if type(items) ~= "table" then
        logger.error("Items must be a table")
        items = {}
    end
    
    -- 序列化数据
    local ok, data = pcall(cjson.encode, items)
    if not ok then
        logger.error("Failed to encode items for user %s: %s", user_id, data)
        return false
    end
    
    -- 设置缓存
    ok = redis.set(key, data)
    if not ok then
        logger.error("Failed to set items cache for user %s", user_id)
        return false
    end
    
    -- 设置过期时间
    ok = redis.expire(key, EXPIRE.user_items)
    if not ok then
        logger.error("Failed to set expire time for user items %s", user_id)
        -- 继续执行，不影响缓存使用
    end
    
    return true
end

-- 删除用户物品缓存
function M.remove_user_items(user_id)
    local key = get_user_items_key(user_id)
    return redis.del(key) > 0
end

-- 获取用户背包
function M.get_user_bag(user_id, bag_type)
    -- 确保参数类型正确
    user_id = tonumber(user_id)
    bag_type = tonumber(bag_type)
    
    if not user_id or not bag_type then
        logger.error("Invalid params for get_user_bag: user_id=%s, bag_type=%s", 
            tostring(user_id), tostring(bag_type))
        return nil
    end

    local key = string.format("user_bag:%d:%d", user_id, bag_type)
    local data = redis.get(key)
    if data then
        local ok, bag = pcall(cjson.decode, data)
        if ok then
            return bag
        end
        logger.error("Failed to decode bag data: %s", data)
    end
    return nil
end

-- 设置单个背包
function M.set_user_bag(user_id, bag_type, bag_data)
    local key = make_key(PREFIX.user_bag, string.format("%d:%d", user_id, bag_type))
    local ok, data = pcall(cjson.encode, bag_data)
    if not ok then
        logger.error("Failed to encode bag data: %s", data)
        return false
    end
    
    ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.user_bag)
    end
    return ok
end

-- 获取用户所有背包
function M.get_user_bags(user_id)
    local key = make_key(PREFIX.user_bags, user_id)
    local data = redis.get(key)
    if data then
        local ok, bags = pcall(cjson.decode, data)
        if ok then
            return bags
        end
        logger.error("Failed to decode bags data: %s", data)
    end
    return nil
end

-- 设置用户所有背包
function M.set_user_bags(user_id, bags)
    local key = make_key(PREFIX.user_bags, user_id)
    local ok, data = pcall(cjson.encode, bags)
    if not ok then
        logger.error("Failed to encode bags data: %s", data)
        return false
    end
    
    ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.user_bags)
    end
    return ok
end

-- 获取背包格子状态
function M.get_bag_slots(user_id, bag_type)
    -- 确保参数类型正确
    user_id = tonumber(user_id)
    bag_type = tonumber(bag_type)
    
    if not user_id or not bag_type then
        logger.error("Invalid params for get_bag_slots: user_id=%s, bag_type=%s", 
            tostring(user_id), tostring(bag_type))
        return nil
    end

    local key = make_key(PREFIX.bag_slots, string.format("%d:%d", user_id, bag_type))
    local data = redis.get(key)
    if data then
        local ok, slots = pcall(cjson.decode, data)
        if ok then
            return slots
        end
        logger.error("Failed to decode slots data: %s", data)
    end
    return nil
end

-- 设置背包格子状态
function M.set_bag_slots(user_id, bag_type, slots)
    local key = make_key(PREFIX.bag_slots, string.format("%d:%d", user_id, bag_type))
    local ok, data = pcall(cjson.encode, slots)
    if not ok then
        logger.error("Failed to encode slots data: %s", data)
        return false
    end
    
    ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.bag_slots)
    end
    return ok
end

-- 背包相关缓存操作
function M.remove_user_bag(user_id, bag_type)
    local key = make_key(PREFIX.user_bag, string.format("%d:%d", user_id, bag_type))
    return redis.del(key) > 0
end

function M.remove_user_bags(user_id)
    local key = make_key(PREFIX.user_bags, user_id)
    return redis.del(key) > 0
end

function M.remove_bag_slots(user_id, bag_type)
    local key = make_key(PREFIX.bag_slots, string.format("%d:%d", user_id, bag_type))
    return redis.del(key) > 0
end

-- 清除用户所有背包相关缓存
function M.clear_bag_cache(user_id)
    -- 清除背包列表缓存
    M.remove_user_bags(user_id)
    
    -- 清除各个背包缓存
    local bag_types = {1, 2, 3}  -- 主背包、仓库、装备栏
    for _, bag_type in ipairs(bag_types) do
        M.remove_user_bag(user_id, bag_type)
        M.remove_bag_slots(user_id, bag_type)
    end
end

return M