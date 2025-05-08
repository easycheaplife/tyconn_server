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

-- 通用键生成函数
local function make_key(prefix, key)
    if type(key) == "number" then
        return string.format("%s%d", prefix, key)  -- 使用 %d 格式化整数
    else
        return prefix .. tostring(key)
    end
end

-- 生成复合键
local function make_composite_key(prefix, format, ...)
    local composite_key = string.format(format, ...)
    return make_key(prefix, composite_key)
end

-- 通用获取缓存函数
local function get_cache(key, debug_info)
    if debug_info then
        logger.debug("Getting cache for %s: %s", debug_info, key)
    end

    local data = redis.get(key)
    if not data then
        return nil
    end

    local success, result = pcall(utils.decode_json, data)
    if not success then
        logger.error("Failed to decode cache data for %s: %s", key, data)
        return nil
    end

    if debug_info then
        logger.debug("Got data from cache: %s", data)
    end

    return result
end

-- 通用设置缓存函数
local function set_cache(key, data, expire_time, debug_info)
    if not data then
        logger.error("Attempt to cache nil data for key: %s", key)
        return false
    end

    if debug_info then
        logger.debug("Setting cache for %s: %s", debug_info, key)
    end

    local json_data = utils.encode_json(data)
    if not json_data then
        logger.error("Failed to encode data for key: %s", key)
        return false
    end

    local ok = redis.set(key, json_data)
    if not ok then
        logger.error("Failed to set cache for key: %s", key)
        return false
    end

    if expire_time then
        redis.expire(key, expire_time)
    end

    return true
end

-- 通用删除缓存函数
local function remove_cache(key)
    return redis.del(key) > 0
end

-- Token相关
function M.get_token(account)
    local key = make_key(PREFIX.token, account)
    return redis.get(key) -- 保持原样，因为token不是JSON格式
end

function M.set_token(account, token)
    local key = make_key(PREFIX.token, account)
    local ok = redis.set(key, token) -- 保持原样，因为token不是JSON格式
    if ok then
        redis.expire(key, EXPIRE.token)
    end
    return ok
end

function M.remove_token(account)
    local key = make_key(PREFIX.token, account)
    return remove_cache(key)
end

-- 用户相关
function M.get_user_info(user_id)
    local key = make_key(PREFIX.user_info, user_id)
    local user = get_cache(key, string.format("user_id: %d", user_id))
    if user then
        logger.debug("Got user from cache: %s", utils.table_to_string(user))
    end
    return user
end

function M.set_user_info(user_id, user)
    local key = make_key(PREFIX.user_info, user_id)
    return set_cache(key, user, EXPIRE.user, string.format("user_id: %d", user_id))
end

function M.remove_user_info(user_id)
    local key = make_key(PREFIX.user_info, user_id)
    return remove_cache(key)
end

-- 通过account获取user_id
function M.get_user_id_by_account(account)
    logger.debug("Getting user ID by account: %s", account)
    local key = make_key(PREFIX.user_account, account)
    local user_id = redis.get(key) -- 保持原样，因为这里存的是纯数字而非JSON
    if user_id then
        return tonumber(user_id)
    end
    return nil
end

-- 缓存account到user_id的映射
function M.set_account_mapping(account, user_id)
    logger.debug("Setting account mapping: %s -> %d", account, user_id)
    local key = make_key(PREFIX.user_account, account)
    local ok = redis.set(key, tostring(user_id)) -- 保持原样，因为这里存的是纯数字而非JSON
    if ok then
        redis.expire(key, EXPIRE.user)
    end
    return ok
end

-- 删除account映射
function M.remove_account_mapping(account)
    local key = make_key(PREFIX.user_account, account)
    return remove_cache(key)
end

-- 卡牌相关
function M.get_user_cards(user_id)
    local key = make_key(PREFIX.user_cards, user_id)
    return get_cache(key, string.format("user cards for user %d", user_id))
end

function M.set_user_cards(user_id, cards)
    local key = make_key(PREFIX.user_cards, user_id)
    local debug_info = string.format("user cards for user %d", user_id)
    logger.debug("Setting %s: %s", debug_info, utils.table_to_string(cards))
    return set_cache(key, cards, EXPIRE.user_cards, debug_info)
end

function M.remove_user_cards(user_id)
    local key = make_key(PREFIX.user_cards, user_id)
    return remove_cache(key)
end

-- 用户物品缓存
function M.get_user_items(user_id)
    if not user_id then
        logger.error("Invalid user_id for getting items")
        return nil
    end

    local key = make_key(PREFIX.user_items, user_id)
    return get_cache(key, string.format("user items for user %d", user_id))
end

function M.set_user_items(user_id, items)
    if not user_id then
        logger.error("Invalid user_id for setting items")
        return false
    end

    -- 确保 items 是数组
    if type(items) ~= "table" then
        logger.error("Items must be a table")
        items = {}
    end

    local key = make_key(PREFIX.user_items, user_id)
    return set_cache(key, items, EXPIRE.user_items, string.format("user items for user %d", user_id))
end

function M.remove_user_items(user_id)
    local key = make_key(PREFIX.user_items, user_id)
    return remove_cache(key)
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

    local composite_key = string.format("%d:%d", user_id, bag_type)
    local key = make_key(PREFIX.user_bag, composite_key)
    return get_cache(key, string.format("user bag %d for user %d", bag_type, user_id))
end

-- 设置单个背包
function M.set_user_bag(user_id, bag_type, bag_data)
    local composite_key = string.format("%d:%d", user_id, bag_type)
    local key = make_key(PREFIX.user_bag, composite_key)
    return set_cache(key, bag_data, EXPIRE.user_bag,
        string.format("user bag %d for user %d", bag_type, user_id))
end

-- 获取用户所有背包
function M.get_user_bags(user_id)
    local key = make_key(PREFIX.user_bags, user_id)
    return get_cache(key, string.format("all bags for user %d", user_id))
end

-- 设置用户所有背包
function M.set_user_bags(user_id, bags)
    local key = make_key(PREFIX.user_bags, user_id)
    return set_cache(key, bags, EXPIRE.user_bags, string.format("all bags for user %d", user_id))
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

    local composite_key = string.format("%d:%d", user_id, bag_type)
    local key = make_key(PREFIX.bag_slots, composite_key)
    return get_cache(key, string.format("bag slots for bag %d of user %d", bag_type, user_id))
end

-- 设置背包格子状态
function M.set_bag_slots(user_id, bag_type, slots)
    local composite_key = string.format("%d:%d", user_id, bag_type)
    local key = make_key(PREFIX.bag_slots, composite_key)
    return set_cache(key, slots, EXPIRE.bag_slots,
        string.format("bag slots for bag %d of user %d", bag_type, user_id))
end

-- 背包相关缓存操作
function M.remove_user_bag(user_id, bag_type)
    local composite_key = string.format("%d:%d", user_id, bag_type)
    local key = make_key(PREFIX.user_bag, composite_key)
    return remove_cache(key)
end

function M.remove_user_bags(user_id)
    local key = make_key(PREFIX.user_bags, user_id)
    return remove_cache(key)
end

function M.remove_bag_slots(user_id, bag_type)
    local composite_key = string.format("%d:%d", user_id, bag_type)
    local key = make_key(PREFIX.bag_slots, composite_key)
    return remove_cache(key)
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
    return get_cache(key, string.format("equipment slots for user %d", user_id))
end

-- 设置用户装备槽
function M.set_equip_slots(user_id, slots)
    local key = make_key(PREFIX.equip_slots, user_id)
    return set_cache(key, slots, EXPIRE.equip_slots,
        string.format("equipment slots for user %d", user_id))
end

-- 获取用户装备等级
function M.get_equip_level(user_id)
    local key = make_key(PREFIX.equip_level, user_id)
    return get_cache(key, string.format("equipment level for user %d", user_id))
end

-- 设置用户装备等级
function M.set_equip_level(user_id, level)
    local key = make_key(PREFIX.equip_level, user_id)
    return set_cache(key, level, EXPIRE.equip_level,
        string.format("equipment level for user %d", user_id))
end

-- 删除用户装备槽缓存
function M.remove_equip_slots(user_id)
    local key = make_key(PREFIX.equip_slots, user_id)
    return remove_cache(key)
end

-- 删除用户装备等级缓存
function M.remove_equip_level(user_id)
    local key = make_key(PREFIX.equip_level, user_id)
    return remove_cache(key)
end

-- 获取装备属性
function M.get_equip_properties(equip_id)
    local key = make_key(PREFIX.equip_props, equip_id)
    return get_cache(key, string.format("equipment properties for equip %d", equip_id))
end

-- 设置装备属性
function M.set_equip_properties(equip_id, props)
    local key = make_key(PREFIX.equip_props, equip_id)
    return set_cache(key, props, EXPIRE.equip_props,
        string.format("equipment properties for equip %d", equip_id))
end

-- 删除装备属性缓存
function M.remove_equip_properties(equip_id)
    local key = make_key(PREFIX.equip_props, equip_id)
    return remove_cache(key)
end

-- 清除用户所有装备相关缓存
function M.clear_equip_cache(user_id)
    M.remove_equip_slots(user_id)
    M.remove_equip_level(user_id)
    -- 注意：装备属性缓存需要具体的装备ID，这里无法清除
    return true
end

-- 获取用户邮件列表
function M.get_user_mails(user_id)
    local key = make_key(PREFIX.user_mails, user_id)
    return get_cache(key, string.format("mails for user %d", user_id))
end

-- 设置用户邮件列表
function M.set_user_mails(user_id, mails)
    -- 确保邮件ID是字符串格式
    for _, mail in ipairs(mails) do
        if mail.id then
            mail.id = tostring(mail.id)
        end
    end

    local key = make_key(PREFIX.user_mails, user_id)
    return set_cache(key, mails, EXPIRE.user_mails,
        string.format("mails for user %d", user_id))
end

-- 删除用户邮件缓存
function M.remove_user_mails(user_id)
    local key = make_key(PREFIX.user_mails, user_id)
    return remove_cache(key)
end

-- 伙伴相关缓存操作
-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    local key = make_key(PREFIX.user_partners, user_id)
    return get_cache(key, string.format("partners for user %d", user_id))
end

-- 设置用户伙伴列表
function M.set_user_partners(user_id, partners)
    local key = make_key(PREFIX.user_partners, user_id)
    local debug_info = string.format("partners for user %d", user_id)
    logger.debug("Setting %s: %s", debug_info, utils.table_to_string(partners))
    return set_cache(key, partners, EXPIRE.user_partners, debug_info)
end

-- 删除用户伙伴列表缓存
function M.remove_user_partners(user_id)
    local key = make_key(PREFIX.user_partners, user_id)
    return remove_cache(key)
end

-- 获取特定伙伴信息
function M.get_partner(partner_id)
    local key = make_key(PREFIX.partner, partner_id)
    return get_cache(key, string.format("partner with id %d", partner_id))
end

-- 设置特定伙伴信息
function M.set_partner(partner_id, partner)
    local key = make_key(PREFIX.partner, partner_id)
    local debug_info = string.format("partner with id %d", partner_id)
    logger.debug("Setting %s: %s", debug_info, utils.table_to_string(partner))
    return set_cache(key, partner, EXPIRE.partner, debug_info)
end

-- 删除特定伙伴信息缓存
function M.remove_partner(partner_id)
    local key = make_key(PREFIX.partner, partner_id)
    return remove_cache(key)
end

-- 地图相关缓存操作

-- 获取用户大富翁状态
function M.get_user_map_info(user_id)
    if not user_id then
        logger.error("cache.get_user_map_info: invalid user_id")
        return nil
    end

    local key = make_key(PREFIX.map_info, user_id)
    return get_cache(key, string.format("map info for user %d", user_id))
end

-- 设置用户大富翁状态
function M.set_user_map_info(user_id, map_info)
    if not user_id or not map_info then
        logger.error("cache.set_user_map_info: invalid parameters")
        return false
    end

    local key = make_key(PREFIX.map_info, user_id)
    return set_cache(key, map_info, EXPIRE.map_info,
        string.format("map info for user %d", user_id))
end

-- 删除用户大富翁状态缓存
function M.remove_user_map_info(user_id)
    if not user_id then
        logger.error("cache.remove_user_map_info: invalid user_id")
        return false
    end

    local key = make_key(PREFIX.map_info, user_id)
    return remove_cache(key)
end

-- 获取章节进度
function M.get_chapter_progress(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("cache.get_chapter_progress: invalid parameters")
        return nil
    end

    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.map_chapter, composite_key)
    return get_cache(key, string.format("chapter %d progress for user %d", chapter_id, user_id))
end

-- 设置章节进度
function M.set_chapter_progress(user_id, chapter_id, progress)
    if not user_id or not chapter_id or not progress then
        logger.error("cache.set_chapter_progress: invalid parameters")
        return false
    end

    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.map_chapter, composite_key)
    return set_cache(key, progress, EXPIRE.map_chapter,
        string.format("chapter %d progress for user %d", chapter_id, user_id))
end

-- 删除章节进度缓存
function M.remove_chapter_progress(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("cache.remove_chapter_progress: invalid parameters")
        return false
    end

    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.map_chapter, composite_key)
    return remove_cache(key)
end

-- 获取格子事件
function M.get_cell_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("cache.get_cell_events: invalid parameters")
        return nil
    end

    local composite_key = string.format("%d:%d", chapter_id, cell_id)
    local key = make_key(PREFIX.map_events, composite_key)
    return get_cache(key, string.format("events for cell %d in chapter %d", cell_id, chapter_id))
end

-- 设置格子事件
function M.set_cell_events(chapter_id, cell_id, events)
    if not chapter_id or not cell_id or not events then
        logger.error("cache.set_cell_events: invalid parameters")
        return false
    end

    local composite_key = string.format("%d:%d", chapter_id, cell_id)
    local key = make_key(PREFIX.map_events, composite_key)
    return set_cache(key, events, EXPIRE.map_events,
        string.format("events for cell %d in chapter %d", cell_id, chapter_id))
end

-- 删除格子事件缓存
function M.remove_cell_events(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("cache.remove_cell_events: invalid parameters")
        return false
    end

    local composite_key = string.format("%d:%d", chapter_id, cell_id)
    local key = make_key(PREFIX.map_events, composite_key)
    return remove_cache(key)
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

-- 注意: 下面的函数已经被上面的 get_cell_events 和 remove_cell_events 替代

-- 注意: 下面的函数已经被上面的 set_cell_events 替代
-- 但是我们保留了一些有用的数据安全检查逻辑

-- 安全处理事件数据的函数
local function clean_events_data(events)
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

    return cleaned_events
end

-- 重写 set_cell_events 函数以包含数据安全检查
function M.set_cell_events(chapter_id, cell_id, events)
    if not chapter_id or not cell_id or not events then
        logger.error("cache.set_cell_events: invalid parameters")
        return false
    end

    -- 安全处理事件数据
    local cleaned_events = clean_events_data(events)

    local composite_key = string.format("%d:%d", chapter_id, cell_id)
    local key = make_key(PREFIX.map_events, composite_key)

    -- 使用通用缓存函数设置数据
    return set_cache(key, cleaned_events, EXPIRE.map_events,
        string.format("events for cell %d in chapter %d", cell_id, chapter_id))
end

-- 为了兼容性添加别名
-- 这些函数与上面的 get_cell_events, set_cell_events 和 remove_cell_events 相同
function M.get_map_events(chapter_id, cell_id)
    return M.get_cell_events(chapter_id, cell_id)
end

function M.set_map_events(chapter_id, cell_id, events)
    return M.set_cell_events(chapter_id, cell_id, events)
end

function M.remove_map_events(chapter_id, cell_id)
    return M.remove_cell_events(chapter_id, cell_id)
end

-- 大富翁随机事件缓存

-- 获取随机事件数量
function M.get_random_event_count(user_id, chapter_id, event_id)
    local composite_key = string.format("%d:%d:%d", user_id, chapter_id, event_id)
    local key = make_key(PREFIX.random_event_count, composite_key)
    local count = redis.get(key) -- 保持原样，因为这里存的是纯数字而非JSON
    if count then
        return tonumber(count)
    end
    return nil
end

-- 设置随机事件数量
function M.set_random_event_count(user_id, chapter_id, event_id, count)
    local composite_key = string.format("%d:%d:%d", user_id, chapter_id, event_id)
    local key = make_key(PREFIX.random_event_count, composite_key)
    local ok = redis.set(key, tostring(count)) -- 保持原样，因为这里存的是纯数字而非JSON
    if ok then
        redis.expire(key, EXPIRE.map_event)
    end
    return ok
end

-- 获取随机事件列表
function M.get_random_events(user_id, chapter_id)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.random_events, composite_key)
    return get_cache(key, string.format("random events for user %d in chapter %d", user_id, chapter_id))
end

-- 设置随机事件列表
function M.set_random_events(user_id, chapter_id, events)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.random_events, composite_key)
    return set_cache(key, events, EXPIRE.map_event,
        string.format("random events for user %d in chapter %d", user_id, chapter_id))
end

-- 删除随机事件列表缓存
function M.remove_random_events(user_id, chapter_id)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.random_events, composite_key)
    return remove_cache(key)
end

-- 获取占用格子列表
function M.get_occupied_cells(user_id, chapter_id)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.occupied_cells, composite_key)
    return get_cache(key, string.format("occupied cells for user %d in chapter %d", user_id, chapter_id))
end

-- 设置占用格子列表
function M.set_occupied_cells(user_id, chapter_id, cells)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.occupied_cells, composite_key)
    return set_cache(key, cells, EXPIRE.map_event,
        string.format("occupied cells for user %d in chapter %d", user_id, chapter_id))
end

-- 删除占用格子列表缓存
function M.remove_occupied_cells(user_id, chapter_id)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    local key = make_key(PREFIX.occupied_cells, composite_key)
    return remove_cache(key)
end

-- 用户已通过章节缓存
function M.get_passed_chapters(user_id)
    if not user_id then
        logger.error("cache.get_passed_chapters: invalid user_id")
        return nil
    end

    local key = make_key(PREFIX.passed_chapters, user_id)
    return get_cache(key, string.format("passed chapters for user %d", user_id))
end

-- 设置用户已通过章节缓存
function M.set_passed_chapters(user_id, chapters)
    if not user_id or not chapters then
        logger.error("cache.set_passed_chapters: invalid parameters")
        return false
    end

    local key = make_key(PREFIX.passed_chapters, user_id)
    return set_cache(key, chapters, EXPIRE.map_chapter,
        string.format("passed chapters for user %d", user_id))
end

-- 删除用户已通过章节缓存
function M.remove_passed_chapters(user_id)
    if not user_id then
        logger.error("cache.remove_passed_chapters: invalid user_id")
        return false
    end

    local key = make_key(PREFIX.passed_chapters, user_id)
    return remove_cache(key)
end

-- 获取事件触发计数
function M.get_event_trigger_count(user_id, chapter_id, event_id)
    local composite_key = string.format("%d:%d:%d", user_id, chapter_id, event_id)
    local key = make_key(PREFIX.event_trigger, composite_key)
    
    return get_cache(key, string.format("event trigger count for user %d, chapter %d, event_id %d", 
        user_id, chapter_id, event_id))
end

-- 设置事件触发计数
function M.set_event_trigger_count(user_id, chapter_id, event_id, trigger_data)
    local composite_key = string.format("%d:%d:%d", user_id, chapter_id, event_id)
    local key = make_key(PREFIX.event_trigger, composite_key)
    
    return set_cache(key, trigger_data, EXPIRE.map_event, 
        string.format("event trigger count for user %d, chapter %d, event_id %d", 
            user_id, chapter_id, event_id))
end

-- 删除事件触发计数缓存
function M.remove_event_trigger_count(user_id, chapter_id, event_id)
    local composite_key = string.format("%d:%d:%d", user_id, chapter_id, event_id)
    local key = make_key(PREFIX.event_trigger, composite_key)
    
    return remove_cache(key)
end

-- 增加事件触发计数（返回增加后的数据）
function M.increment_event_trigger_count(user_id, chapter_id, event_id)
    local trigger_data = M.get_event_trigger_count(user_id, chapter_id, event_id)
    local current_time = os.time()
    
    -- 如果没有记录，创建一个新的
    if not trigger_data then
        trigger_data = {
            user_id = user_id,
            chapter_id = chapter_id,
            event_id = event_id,
            trigger_count = 1,
            create_time = current_time,
            update_time = current_time
        }
    else
        -- 增加计数
        trigger_data.trigger_count = trigger_data.trigger_count + 1
        trigger_data.update_time = current_time
    end
    
    -- 更新缓存
    M.set_event_trigger_count(user_id, chapter_id, event_id, trigger_data)
    
    return trigger_data
end

-- 获取GM骰子点数
function M.get_gm_dice_num()
    local key = make_key(PREFIX.gm_dice_num, "global")
    local value = redis.get(key)
    if value then
        logger.debug("Got GM dice num from cache: %s", value)
        return tonumber(value)
    end
    return nil
end

-- 设置GM骰子点数
function M.set_gm_dice_num(num)
    local key = make_key(PREFIX.gm_dice_num, "global")
    if num == nil then
        logger.debug("Removing GM dice num from cache")
        return redis.del(key) > 0
    end
    
    logger.debug("Setting GM dice num to cache: %s", tostring(num))
    local ok = redis.set(key, tostring(num))
    if ok then
        redis.expire(key, EXPIRE.gm_dice_num)
    end
    return ok
end

-- 删除GM骰子点数缓存
function M.remove_gm_dice_num()
    local key = make_key(PREFIX.gm_dice_num, "global")
    logger.debug("Removing GM dice num cache")
    return remove_cache(key)
end

-- 事件触发记录缓存key
local function make_chapter_triggers_key(user_id, chapter_id)
    local composite_key = string.format("%d:%d", user_id, chapter_id)
    return make_key(PREFIX.event_triggers, composite_key)
end

-- 获取章节的所有事件触发记录
function M.get_chapter_event_triggers(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("cache.get_chapter_event_triggers: invalid parameters")
        return nil
    end

    local key = make_chapter_triggers_key(user_id, chapter_id)
    return get_cache(key, string.format("event triggers for user %d, chapter %d", user_id, chapter_id))
end

-- 设置章节的所有事件触发记录
function M.set_chapter_event_triggers(user_id, chapter_id, triggers)
    if not user_id or not chapter_id or not triggers then
        logger.error("cache.set_chapter_event_triggers: invalid parameters")
        return false
    end

    local key = make_chapter_triggers_key(user_id, chapter_id)
    return set_cache(key, triggers, EXPIRE.event_triggers or EXPIRE.map_event,
        string.format("event triggers for user %d, chapter %d", user_id, chapter_id))
end

-- 删除章节的所有事件触发记录缓存
function M.remove_chapter_event_triggers(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("cache.remove_chapter_event_triggers: invalid parameters")
        return false
    end

    local key = make_chapter_triggers_key(user_id, chapter_id)
    return remove_cache(key)
end

return M