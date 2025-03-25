local skynet = require "skynet"
local logger = require "logger"
local db_client = require "game.db_client"
local cache = require "game.cache"
local item_model = require "models.item_model"
local utils = require "utils"

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

-- 更新单个物品
function M.update_single_item(item)
    if not item or not item.id or not item.user_id then
        logger.error("Invalid item for update_single_item: %s", utils.table_to_string(item or {}))
        return false, "参数无效"
    end
    
    -- 1. 更新数据库中的单条记录
    local ok = db_client.update_single_item(item)
    if not ok then
        logger.error("Failed to update single item in DB: user_id=%d, item_id=%d, id=%s",
            item.user_id, item.item_id, tostring(item.id))
        return false, "更新失败"
    end
    
    -- 2. 更新缓存（需要先获取完整的物品列表）
    local items = M.get_user_items(item.user_id)
    if items then
        for i, existing_item in ipairs(items) do
            if existing_item.id == item.id then
                -- 替换物品
                items[i] = item
                break
            end
        end
        
        -- 更新缓存
        cache.set_user_items(item.user_id, items)
    end
    
    return true
end

-- 添加单个物品
function M.add_single_item(item)
    if not item or not item.user_id or not item.item_id then
        logger.error("Invalid item for add_single_item: %s", utils.table_to_string(item or {}))
        return false, "参数无效"
    end
    
    -- 确保物品有ID
    if not item.id then
        logger.error("Item must have an ID for add_single_item")
        return false, "物品缺少ID"
    end
    
    -- 1. 添加到数据库
    local ok = db_client.add_single_item(item)
    if not ok then
        logger.error("Failed to add single item to DB: user_id=%d, item_id=%d",
            item.user_id, item.item_id)
        return false, "添加失败"
    end
    
    -- 2. 更新缓存（需要先获取完整的物品列表）
    local items = M.get_user_items(item.user_id)
    if items then
        -- 添加新物品到缓存列表
        table.insert(items, item)
        
        -- 更新缓存
        cache.set_user_items(item.user_id, items)
    end
    
    return true
end

-- 删除单个物品
function M.delete_single_item(item_id, user_id)
    if not item_id or not user_id then
        logger.error("Invalid params for delete_single_item")
        return false, "参数无效"
    end
    
    -- 1. 从数据库删除
    local ok = db_client.delete_single_item(item_id, user_id)
    if not ok then
        logger.error("Failed to delete single item from DB: user_id=%d, item_id=%s",
            user_id, tostring(item_id))
        return false, "删除失败"
    end
    
    -- 2. 更新缓存（需要先获取完整的物品列表）
    local items = M.get_user_items(user_id)
    if items then
        -- 过滤掉被删除的物品
        local new_items = {}
        for _, item in ipairs(items) do
            if item.id ~= item_id then
                table.insert(new_items, item)
            end
        end
        
        -- 更新缓存
        cache.set_user_items(user_id, new_items)
    end
    
    return true
end

return M 