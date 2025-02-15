local skynet = require "skynet"
local logger = require "logger"
local db_client = require "game.db_client"
local cache = require "game.cache"
local utils = require "utils"

local M = {}

-- 物品变化类型
M.CHANGE_TYPE = {
    ADD = 1,    -- 增加
    REDUCE = 2, -- 减少
    USE = 3,    -- 使用
}

-- 物品变化来源
M.CHANGE_SOURCE = {
    INIT = "init",       -- 初始化
    REWARD = "reward",   -- 奖励
    USE = "use",        -- 使用
}

-- 新手默认物品
local DEFAULT_ITEMS = {
    {
        item_id = 1001,  -- 初级经验药水
        count = 2
    },
    {
        item_id = 2001,  -- 金币
        count = 1000
    }
}

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
    cache.set_user_items(user_id, result)

    return result
end

-- 添加物品
function M.add_items(user_id, items)
    if not user_id or not items then
        return false, "参数无效"
    end

    -- 1. 获取当前物品
    local current_items = M.get_user_items(user_id) or {}
    
    -- 2. 合并物品
    for _, item in ipairs(items) do
        local found = false
        for _, curr_item in ipairs(current_items) do
            if curr_item.item_id == item.item_id then
                -- 记录变更前数量
                local before_count = curr_item.count
                curr_item.count = curr_item.count + (item.count or 1)
                curr_item.update_time = os.time()
                
                -- 记录物品变化
                M.log_change(user_id, item.item_id, item.count, 
                    M.CHANGE_TYPE.ADD, M.CHANGE_SOURCE.REWARD,
                    before_count, curr_item.count)
                found = true
                break
            end
        end
        
        if not found then
            -- 新增物品
            local new_item = {
                user_id = user_id,
                item_id = item.item_id,
                count = item.count or 1,
                create_time = os.time(),
                update_time = os.time()
            }
            table.insert(current_items, new_item)
            
            -- 记录物品变化
            M.log_change(user_id, item.item_id, new_item.count,
                M.CHANGE_TYPE.ADD, M.CHANGE_SOURCE.REWARD,
                0, new_item.count)
        end
    end

    -- 3. 更新数据库
    local ok = db_client.update_user_items(user_id, current_items)
    if not ok then
        return false, "更新失败"
    end

    -- 4. 更新缓存
    cache.set_user_items(user_id, current_items)

    return true
end

-- 使用物品
function M.use_item(user_id, item_id, count)
    if not user_id or not item_id or not count or count <= 0 then
        return false, "参数无效"
    end

    -- 1. 获取物品
    local items = M.get_user_items(user_id)
    if not items then
        return false, "物品不存在"
    end

    -- 2. 查找并使用物品
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            if item.count < count then
                return false, "物品数量不足"
            end

            -- 记录变更前数量
            local before_count = item.count
            
            -- 更新数量
            item.count = item.count - count
            item.update_time = os.time()

            -- 记录物品变化
            M.log_change(user_id, item_id, count,
                M.CHANGE_TYPE.USE, M.CHANGE_SOURCE.USE,
                before_count, item.count)

            -- 3. 更新数据库
            local ok = db_client.update_user_items(user_id, items)
            if not ok then
                return false, "更新失败"
            end

            -- 4. 更新缓存
            cache.set_user_items(user_id, items)

            return true, item
        end
    end

    return false, "物品不存在"
end

-- 记录物品变化
function M.log_change(user_id, item_id, count, type, source, before_count, after_count)
    return db_client.log_item_change(
        user_id, item_id, count, type, source, before_count, after_count
    )
end

-- 初始化新用户物品
function M.init_user_items(user_id)
    if not user_id then
        return false, "无效的用户ID"
    end

    logger.info("Initializing items for new user: %d", user_id)
    
    -- 添加默认物品
    local ok = M.add_items(user_id, DEFAULT_ITEMS)
    if not ok then
        logger.error("Failed to add default items for user: %d", user_id)
        return false, "添加默认物品失败"
    end

    -- 记录日志
    for _, item in ipairs(DEFAULT_ITEMS) do
        M.log_change(user_id, item.item_id, item.count, 
            M.CHANGE_TYPE.ADD, M.CHANGE_SOURCE.INIT, 0, item.count)
    end

    return true
end

return M 