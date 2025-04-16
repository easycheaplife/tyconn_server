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
        local user = utils.decode_json(data)
        if user then
            logger.debug("Got user from cache: %s", utils.table_to_string(user))
            return user
        end
        logger.error("Failed to decode user data: %s", data)
    end
    return nil
end

function M.set_user_info(user_id, user)
    local key = make_key(PREFIX.user_info, user_id)
    local data = utils.encode_json(user)
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
        return utils.decode_json(data)
    end
    return nil
end

function M.set_user_cards(user_id, cards)
    logger.debug("Setting user cards for user %d: %s", user_id, utils.table_to_string(cards))
    local key = make_key(PREFIX.user_cards, user_id)
    local data = utils.encode_json(cards)
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
        local items = utils.decode_json(data)
        if items then
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
    local data = utils.encode_json(items)
    if not data then
        logger.error("Failed to encode items for user %s", user_id)
        return false
    end
    
    -- 设置缓存
    local ok = redis.set(key, data)
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
        local bag = utils.decode_json(data)
        if bag then
            return bag
        end
        logger.error("Failed to decode bag data: %s", data)
    end
    return nil
end

-- 设置单个背包
function M.set_user_bag(user_id, bag_type, bag_data)
    local key = make_key(PREFIX.user_bag, string.format("%d:%d", user_id, bag_type))
    local data = utils.encode_json(bag_data)
    if not data then
        logger.error("Failed to encode bag data")
        return false
    end
    
    local ok = redis.set(key, data)
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
        local bags = utils.decode_json(data)
        if bags then
            return bags
        end
        logger.error("Failed to decode bags data: %s", data)
    end
    return nil
end

-- 设置用户所有背包
function M.set_user_bags(user_id, bags)
    local key = make_key(PREFIX.user_bags, user_id)
    local data = utils.encode_json(bags)
    if not data then
        logger.error("Failed to encode bags data")
        return false
    end
    
    local ok = redis.set(key, data)
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
        local slots = utils.decode_json(data)
        if slots then
            return slots
        end
        logger.error("Failed to decode slots data: %s", data)
    end
    return nil
end

-- 设置背包格子状态
function M.set_bag_slots(user_id, bag_type, slots)
    local key = make_key(PREFIX.bag_slots, string.format("%d:%d", user_id, bag_type))
    local data = utils.encode_json(slots)
    if not data then
        logger.error("Failed to encode slots data")
        return false
    end
    
    local ok = redis.set(key, data)
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

-- 获取用户装备槽
function M.get_equip_slots(user_id)
    local key = make_key(PREFIX.equip_slots, user_id)
    local data = redis.get(key)
    if data then
        local slots = utils.decode_json(data)
        if slots then
            return slots
        end
        logger.error("Failed to decode equipment slots data: %s", data)
    end
    return nil
end

-- 设置用户装备槽
function M.set_equip_slots(user_id, slots)
    local key = make_key(PREFIX.equip_slots, user_id)
    local data = utils.encode_json(slots)
    if not data then
        logger.error("Failed to encode equipment slots data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.equip_slots)
    end
    return ok
end

-- 获取用户装备等级
function M.get_equip_level(user_id)
    local key = make_key(PREFIX.equip_level, user_id)
    local data = redis.get(key)
    if data then
        local level = utils.decode_json(data)
        if level then
            return level
        end
        logger.error("Failed to decode equipment level data: %s", data)
    end
    return nil
end

-- 设置用户装备等级
function M.set_equip_level(user_id, level)
    local key = make_key(PREFIX.equip_level, user_id)
    local data = utils.encode_json(level)
    if not data then
        logger.error("Failed to encode equipment level data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.equip_level)
    end
    return ok
end

-- 删除用户装备槽缓存
function M.remove_equip_slots(user_id)
    local key = make_key(PREFIX.equip_slots, user_id)
    return redis.del(key) > 0
end

-- 删除用户装备等级缓存
function M.remove_equip_level(user_id)
    local key = make_key(PREFIX.equip_level, user_id)
    return redis.del(key) > 0
end

-- 清除用户所有装备相关缓存
function M.clear_equip_cache(user_id)
    M.remove_equip_slots(user_id)
    M.remove_equip_level(user_id)
    return true
end

-- 获取用户邮件列表
function M.get_user_mails(user_id)
    local key = make_key(PREFIX.user_mails, user_id)
    local data = redis.get(key)
    if data then
        local mails = utils.decode_json(data)
        if mails then
            return mails
        end
        logger.error("Failed to decode mails data: %s", data)
    end
    return nil
end

-- 设置用户邮件列表
function M.set_user_mails(user_id, mails)
    local key = make_key(PREFIX.user_mails, user_id)
    -- 确保邮件ID是字符串格式
    for _, mail in ipairs(mails) do
        if mail.id then
            mail.id = tostring(mail.id)
        end
    end
    local data = utils.encode_json(mails)
    if not data then
        logger.error("Failed to encode mails data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.user_mails)
    end
    return ok
end

-- 删除用户邮件缓存
function M.remove_user_mails(user_id)
    local key = make_key(PREFIX.user_mails, user_id)
    return redis.del(key) > 0
end

-- 伙伴相关缓存操作
-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    logger.debug("Getting user partners for user %d", user_id)
    local key = make_key(PREFIX.user_partners, user_id)
    logger.debug("Cache key: %s", key)
    local data = redis.get(key)
    if data then
        logger.debug("Got partners from cache: %s", data)
        return utils.decode_json(data)
    end
    return nil
end

-- 设置用户伙伴列表
function M.set_user_partners(user_id, partners)
    logger.debug("Setting user partners for user %d: %s", user_id, utils.table_to_string(partners))
    local key = make_key(PREFIX.user_partners, user_id)
    local data = utils.encode_json(partners)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.user_partners)
    end
    return ok
end

-- 删除用户伙伴列表缓存
function M.remove_user_partners(user_id)
    local key = make_key(PREFIX.user_partners, user_id)
    return redis.del(key) > 0
end

-- 获取特定伙伴信息
function M.get_partner(partner_id)
    logger.debug("Getting partner info for partner_id %d", partner_id)
    local key = make_key(PREFIX.partner, partner_id)
    local data = redis.get(key)
    if data then
        logger.debug("Got partner from cache: %s", data)
        return utils.decode_json(data)
    end
    return nil
end

-- 设置特定伙伴信息
function M.set_partner(partner_id, partner)
    logger.debug("Setting partner for partner_id %d: %s", partner_id, utils.table_to_string(partner))
    local key = make_key(PREFIX.partner, partner_id)
    local data = utils.encode_json(partner)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.partner)
    end
    return ok
end

-- 删除特定伙伴信息缓存
function M.remove_partner(partner_id)
    local key = make_key(PREFIX.partner, partner_id)
    return redis.del(key) > 0
end

-- 地图相关缓存操作

-- 获取用户大富翁状态
function M.get_user_map_info(user_id)
    if not user_id then
        logger.error("cache.get_user_map_info: invalid user_id")
        return nil
    end
    
    local key = make_key(PREFIX.map_info, user_id)
    local data = redis.get(key)
    if data then
        local map_info = utils.decode_json(data)
        if map_info then
            return map_info
        end
        logger.error("Failed to decode map info data: %s", data)
    end
    return nil
end

-- 设置用户大富翁状态
function M.set_user_map_info(user_id, map_info)
    if not user_id or not map_info then
        logger.error("cache.set_user_map_info: invalid parameters")
        return false
    end
    
    local key = make_key(PREFIX.map_info, user_id)
    local data = utils.encode_json(map_info)
    if not data then
        logger.error("Failed to encode map info data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.map_info)
    end
    return ok
end

-- 删除用户大富翁状态缓存
function M.remove_user_map_info(user_id)
    if not user_id then
        logger.error("cache.remove_user_map_info: invalid user_id")
        return false
    end
    
    local key = make_key(PREFIX.map_info, user_id)
    return redis.del(key) > 0
end

-- 获取章节进度
function M.get_chapter_progress(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("cache.get_chapter_progress: invalid parameters")
        return nil
    end
    
    local key = make_key(PREFIX.map_chapter, string.format("%d:%d", user_id, chapter_id))
    local data = redis.get(key)
    if data then
        local progress = utils.decode_json(data)
        if progress then
            return progress
        end
        logger.error("Failed to decode chapter progress data: %s", data)
    end
    return nil
end

-- 设置章节进度
function M.set_chapter_progress(user_id, chapter_id, progress)
    if not user_id or not chapter_id or not progress then
        logger.error("cache.set_chapter_progress: invalid parameters")
        return false
    end
    
    local key = make_key(PREFIX.map_chapter, string.format("%d:%d", user_id, chapter_id))
    local data = utils.encode_json(progress)
    if not data then
        logger.error("Failed to encode chapter progress data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.map_chapter)
    end
    return ok
end

-- 删除章节进度缓存
function M.remove_chapter_progress(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("cache.remove_chapter_progress: invalid parameters")
        return false
    end
    
    local key = make_key(PREFIX.map_chapter, string.format("%d:%d", user_id, chapter_id))
    return redis.del(key) > 0
end

-- 获取格子事件
function M.get_cell_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("cache.get_cell_events: invalid parameters")
        return nil
    end
    
    local key = make_key(PREFIX.map_events, string.format("%d:%d", chapter_id, cell_id))
    local data = redis.get(key)
    if data then
        local events = utils.decode_json(data)
        if events then
            return events
        end
        logger.error("Failed to decode cell events data: %s", data)
    end
    return nil
end

-- 设置格子事件
function M.set_cell_events(chapter_id, cell_id, events)
    if not chapter_id or not cell_id or not events then
        logger.error("cache.set_cell_events: invalid parameters")
        return false
    end
    
    local key = make_key(PREFIX.map_events, string.format("%d:%d", chapter_id, cell_id))
    local data = utils.encode_json(events)
    if not data then
        logger.error("Failed to encode cell events data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.map_events)
    end
    return ok
end

-- 删除格子事件缓存
function M.remove_cell_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("cache.remove_cell_events: invalid parameters")
        return false
    end
    
    local key = make_key(PREFIX.map_events, string.format("%d:%d", chapter_id, cell_id))
    return redis.del(key) > 0
end

-- 清除用户所有大富翁相关缓存
function M.clear_map_cache(user_id, chapter_id)
    if not user_id then
        logger.error("cache.clear_map_cache: invalid user_id")
        return false
    end
    
    -- 清除用户大富翁状态
    M.remove_user_map_info(user_id)
    
    -- 如果指定了章节ID，只清除该章节的缓存
    if chapter_id then
        M.remove_chapter_progress(user_id, chapter_id)
    else
        -- TODO: 如果需要清除所有章节进度，这里需要知道用户有哪些章节
        -- 暂时不实现
    end
    
    return true
end

-- 清除地图事件缓存
function M.remove_map_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("Invalid parameters for remove_map_events")
        return false
    end

    local key = string.format("%s%d:%d", PREFIX.map_events, chapter_id, cell_id)
    local ok, err = pcall(function()
        return redis.del(key)
    end)

    if not ok then
        logger.error("Failed to remove map events cache: %s", tostring(err))
        return false
    end

    return true
end

-- 获取地图事件缓存
function M.get_map_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("Invalid parameters for get_map_events")
        return nil
    end

    local key = string.format("%s%d:%d", PREFIX.map_events, chapter_id, cell_id)
    local ok, result = pcall(function()
        return redis.get(key)
    end)

    if not ok then
        logger.error("Failed to get map events cache: %s", tostring(result))
        return nil
    end

    if not result then
        return nil
    end

    local success, data = pcall(cjson.decode, result)
    if not success then
        logger.error("Failed to decode map events cache: %s", tostring(data))
        return nil
    end

    return data
end

-- 设置地图事件缓存
function M.set_map_events(chapter_id, cell_id, events)
    if not chapter_id or not cell_id then
        logger.error("Invalid parameters for set_map_events: chapter_id=%s, cell_id=%s", 
            tostring(chapter_id), tostring(cell_id))
        return false
    end
    
    if not events then
        logger.error("Events data is nil in set_map_events")
        return false
    end
    
    -- 构建缓存key
    local key = string.format("%s%d:%d", PREFIX.map_events, chapter_id, cell_id)
    
    -- 数据安全检查 - 清理可能导致序列化问题的数据
    local cleaned_events = {}
    local max_events = 50 -- 限制最大事件数量
    
    for i, event in ipairs(events) do
        if i > max_events then 
            logger.warn("Too many events for cache, truncating to %d events", max_events)
            break
        end
        
        -- 创建事件的安全副本，只保留必要字段
        local safe_event = {
            id = event.id,
            user_id = event.user_id,
            chapter_id = event.chapter_id,
            cell_id = event.cell_id,
            event_id = event.event_id,
            status = event.status,
            is_random_event = event.is_random_event,
            trigger_time = event.trigger_time,
            complete_time = event.complete_time
        }
        
        table.insert(cleaned_events, safe_event)
    end
    
    -- 将事件数据转换为JSON字符串
    local ok, value = pcall(utils.encode_json, cleaned_events)
    if not ok then
        logger.error("Failed to encode events data to JSON: %s", tostring(value))
        return false
    end
    
    -- 检查序列化后的数据大小
    if #value > 1024 * 1024 then  -- 1MB 限制
        logger.error("Events data too large for Redis cache: %d bytes", #value)
        return false
    end
    
    -- 使用pcall保护Redis操作
    local set_ok, set_err = pcall(function()
        -- 使用Redis设置缓存
        local redis_ok = redis.set(key, value)
        if redis_ok then
            redis.expire(key, EXPIRE.map_events)
        end
        return redis_ok
    end)
    
    if not set_ok then
        logger.error("Redis error in set_map_events: %s", tostring(set_err))
        return false
    end
    
    return set_ok
end

-- 获取地图事件数据从缓存
function M.get_map_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("Invalid parameters for get_map_events: chapter_id=%s, cell_id=%s", 
            tostring(chapter_id), tostring(cell_id))
        return nil
    end
    
    -- 构建缓存key
    local key = string.format("%s%d:%d", PREFIX.map_events, chapter_id, cell_id)
    
    -- 从Redis获取缓存
    local value, err = redis.get(key)
    if not value then
        if err then
            logger.error("Failed to get map events cache: %s", tostring(err))
        end
        return nil
    end
    
    -- 解析JSON数据
    local ok, events = pcall(utils.decode_json, value)
    if not ok then
        logger.error("Failed to decode map events cache: %s", tostring(events))
        return nil
    end
    
    return events
end

-- 删除地图事件缓存
function M.remove_map_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("Invalid parameters for remove_map_events: chapter_id=%s, cell_id=%s", 
            tostring(chapter_id), tostring(cell_id))
        return false
    end
    
    -- 构建缓存key
    local key = string.format("%s%d:%d", PREFIX.map_events, chapter_id, cell_id)
    
    -- 从Redis删除缓存
    local ok, err = redis.del(key)
    if not ok then
        logger.error("Failed to remove map events cache: %s", tostring(err))
        return false
    end
    
    return true
end

-- 大富翁随机事件缓存

-- 随机事件数量缓存键
local function get_random_event_count_key(user_id, chapter_id, event_id)
    return make_key(PREFIX.random_event_count, string.format("%d:%d:%d", user_id, chapter_id, event_id))
end

-- 获取随机事件数量
function M.get_random_event_count(user_id, chapter_id, event_id)
    local key = get_random_event_count_key(user_id, chapter_id, event_id)
    local count = redis.get(key)
    if count then
        return tonumber(count)
    end
    return nil
end

-- 设置随机事件数量
function M.set_random_event_count(user_id, chapter_id, event_id, count)
    local key = get_random_event_count_key(user_id, chapter_id, event_id)
    local ok = redis.set(key, tostring(count))
    if ok then
        redis.expire(key, EXPIRE.map_event)
    end
    return ok
end

-- 随机事件列表缓存键
local function get_random_events_key(user_id, chapter_id)
    return make_key(PREFIX.random_events, string.format("%d:%d", user_id, chapter_id))
end

-- 获取随机事件列表
function M.get_random_events(user_id, chapter_id)
    local key = get_random_events_key(user_id, chapter_id)
    local data = redis.get(key)
    if data then
        return utils.decode_json(data)
    end
    return nil
end

-- 设置随机事件列表
function M.set_random_events(user_id, chapter_id, events)
    local key = get_random_events_key(user_id, chapter_id)
    local data = utils.encode_json(events)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.map_event)
    end
    return ok
end

-- 删除随机事件列表缓存
function M.remove_random_events(user_id, chapter_id)
    local key = get_random_events_key(user_id, chapter_id)
    return redis.del(key) > 0
end

-- 占用格子缓存键
local function get_occupied_cells_key(user_id, chapter_id)
    return make_key(PREFIX.occupied_cells, string.format("%d:%d", user_id, chapter_id))
end

-- 获取占用格子列表
function M.get_occupied_cells(user_id, chapter_id)
    local key = get_occupied_cells_key(user_id, chapter_id)
    local data = redis.get(key)
    if data then
        return utils.decode_json(data)
    end
    return nil
end

-- 设置占用格子列表
function M.set_occupied_cells(user_id, chapter_id, cells)
    local key = get_occupied_cells_key(user_id, chapter_id)
    local data = utils.encode_json(cells)
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.map_event)
    end
    return ok
end

-- 删除占用格子列表缓存
function M.remove_occupied_cells(user_id, chapter_id)
    local key = get_occupied_cells_key(user_id, chapter_id)
    return redis.del(key) > 0
end

-- 用户已通过章节缓存
function M.get_passed_chapters(user_id)
    if not user_id then
        logger.error("cache.get_passed_chapters: invalid user_id")
        return nil
    end
    
    local key = make_key(PREFIX.passed_chapters, user_id)
    local data = redis.get(key)
    if data then
        local chapters = utils.decode_json(data)
        if chapters then
            return chapters
        end
        logger.error("Failed to decode passed chapters data: %s", data)
    end
    return nil
end

-- 设置用户已通过章节缓存
function M.set_passed_chapters(user_id, chapters)
    if not user_id or not chapters then
        logger.error("cache.set_passed_chapters: invalid parameters")
        return false
    end
    
    local key = make_key(PREFIX.passed_chapters, user_id)
    local data = utils.encode_json(chapters)
    if not data then
        logger.error("Failed to encode passed chapters data")
        return false
    end
    
    local ok = redis.set(key, data)
    if ok then
        redis.expire(key, EXPIRE.map_chapter)
    end
    return ok
end

-- 删除用户已通过章节缓存
function M.remove_passed_chapters(user_id)
    if not user_id then
        logger.error("cache.remove_passed_chapters: invalid user_id")
        return false
    end
    
    local key = make_key(PREFIX.passed_chapters, user_id)
    return redis.del(key) > 0
end

return M