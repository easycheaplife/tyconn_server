local skynet = require "skynet"
local logger = require "logger"
local db_client = require "game.db_client"
local cache = require "game.cache"
local item_model = require "models.item_model"

local M = {}

-- 获取用户物品列表
function M.get_user_items(user_id)
    if not user_id then
        return nil, "无效的用户ID"
    end

    -- 1. 从缓存获取
    local items = cache.get_user_items(user_id)
    if items then
        -- 确保数值类型
        for _, item in ipairs(items) do
            item.item_id = tonumber(item.item_id)
            item.count = tonumber(item.count)
            item.slot_index = tonumber(item.slot_index or 0)
            item.bag_type = tonumber(item.bag_type)
        end
        return items
    end

    -- 2. 从数据库获取
    local result = db_client.get_user_items(user_id)
    if not result then
        return {}, "获取物品失败"
    end

    -- 确保数值类型
    for _, item in ipairs(result) do
        item.item_id = tonumber(item.item_id)
        item.count = tonumber(item.count)
        item.slot_index = tonumber(item.slot_index or 0)
        item.bag_type = tonumber(item.bag_type)
    end

    -- 3. 写入缓存
    if #result > 0 then
        cache.set_user_items(user_id, result)
    end

    return result
end

-- 更新用户物品
function M.update_user_items(user_id, items)
    if not user_id or not items then
        return false, "参数无效"
    end

    -- 1. 更新数据库
    local ok = db_client.update_user_items(user_id, items)
    if not ok then
        return false, "更新失败"
    end

    -- 2. 更新缓存
    cache.set_user_items(user_id, items)

    return true
end

-- 记录物品变化日志
function M.log_change(user_id, item_id, count, type, source, before_count, after_count)
    -- 创建日志记录
    local log = item_model.new_change_log({
        user_id = user_id,
        item_id = item_id,
        count = count,
        type = type,
        source = source,
        before_count = before_count,
        after_count = after_count
    })

    return db_client.log_item_change(
        log.user_id, log.item_id, log.count, 
        log.type, log.source, 
        log.before_count, log.after_count
    )
end

-- 清除用户物品缓存
function M.clear_user_items_cache(user_id)
    if not user_id then
        return false
    end
    return cache.remove_user_items(user_id)
end

-- 获取物品使用次数
function M.get_use_count(user_id, item_id)
    -- 1. 从缓存获取
    local key = string.format("item_use_count:%d:%d", user_id, item_id)
    local count = cache.get(key)
    if count then
        return tonumber(count)
    end
    
    -- 2. 从数据库获取
    local result = db_client.get_item_use_count(user_id, item_id)
    if not result then
        return 0
    end
    
    -- 3. 写入缓存
    cache.set(key, result.count)
    
    return result.count
end

-- 更新物品使用次数
function M.update_use_count(user_id, item_id, count)
    -- 1. 更新数据库
    local ok = db_client.update_item_use_count(user_id, item_id, count)
    if not ok then
        return false
    end
    
    -- 2. 更新缓存
    local key = string.format("item_use_count:%d:%d", user_id, item_id)
    cache.set(key, count)
    
    return true
end

-- 获取最后使用时间
function M.get_last_use_time(user_id, item_id)
    -- 1. 从缓存获取
    local key = string.format("item_last_use:%d:%d", user_id, item_id)
    local time = cache.get(key)
    if time then
        return tonumber(time)
    end
    
    -- 2. 从数据库获取
    local result = db_client.get_item_last_use(user_id, item_id)
    if not result then
        return nil
    end
    
    -- 3. 写入缓存
    cache.set(key, result.time)
    
    return result.time
end

-- 记录交易日志
function M.log_trade(from_user, to_user, item_id, count)
    return db_client.log_item_trade({
        from_user = from_user,
        to_user = to_user,
        item_id = item_id,
        count = count,
        time = os.time()
    })
end

return M 