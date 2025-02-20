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
        return items
    end

    -- 2. 从数据库获取
    local result = db_client.get_user_items(user_id)
    if not result then
        return {}, "获取物品失败"
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

return M 