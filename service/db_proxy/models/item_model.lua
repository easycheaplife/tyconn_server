local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.item_sql"
local db_util = require "db_proxy.utils.db_util"

local M = {}

-- 获取用户物品列表
function M.get_user_items(user_id)
    local results = db_util.execute(sql.GET_USER_ITEMS, {
        user_id = user_id
    })
    
    if not results then
        logger.error("Failed to get items for user: %d", user_id)
        return nil, "Database error"
    end
    -- 确保返回所有必要字段
    for _, item in ipairs(results) do
        item.count = item.count or 0
    end
    
    return results
end

-- 更新用户物品列表
function M.update_user_items(user_id, items)
    if not user_id or not items then
        return false, "Invalid parameters"
    end

    -- 使用事务确保原子性操作
    return db_util.transaction(function()
        -- 先删除旧数据
        local ok = db_util.execute(sql.DELETE_USER_ITEMS, {
            user_id = user_id
        })
        if not ok then
            logger.error("Failed to delete old items for user: %d", user_id)
            return false, "Database error - failed to delete old items"
        end

        -- 如果有新数据，批量插入
        if #items > 0 then
            local values = {}
            for _, item in ipairs(items) do
                table.insert(values, string.format(
                    "(%d, %d, %d, %d, %d, %d, %d, %d)",
                    item.id,
                    user_id,
                    item.item_id,
                    item.count,
                    item.bag_type or 1,  -- 默认主背包
                    item.slot_index or 0, -- 默认0号位
                    item.create_time,
                    item.update_time
                ))
            end

            ok = db_util.execute(sql.INSERT_ITEMS, {
                values = table.concat(values, ",")
            })
            if not ok then
                logger.error("Failed to insert new items for user: %d", user_id)
                return false, "Database error - failed to insert new items"
            end
        end

        logger.info("Successfully updated %d items for user %d", #items, user_id)
        return true
    end)
end

-- 记录物品变化
function M.log_item_change(log)
    if not log or not log.user_id or not log.item_id then
        return false, "Invalid parameters"
    end

    local ok = db_util.execute(sql.LOG_ITEM_CHANGE, {
        user_id = log.user_id,
        item_id = log.item_id,
        count = log.count,
        type = log.type,
        source = log.source,
        before_count = log.before_count,
        after_count = log.after_count,
        create_time = log.create_time
    })

    if not ok then
        logger.error("Failed to log item change for user: %d, item_id: %d",
            log.user_id, log.item_id)
        return false, "Database error"
    end

    return true
end

-- 更新单个物品
function M.update_single_item(item)
    if not item or not item.id or not item.user_id then
        return false, "Invalid parameters"
    end

    local ok = db_util.execute(sql.UPDATE_SINGLE_ITEM, {
        id = item.id,
        user_id = item.user_id,
        item_id = item.item_id,
        count = item.count,
        bag_type = item.bag_type,
        slot_index = item.slot_index,
        update_time = item.update_time or os.time()
    })

    if not ok then
        logger.error("Failed to update single item for user: %d, item_id: %d, id: %d",
            item.user_id, item.item_id, item.id)
        return false, "Database error"
    end

    logger.info("Successfully updated single item for user %d, item_id %d, id %d",
        item.user_id, item.item_id, item.id)
    return true
end

-- 添加单个物品
function M.add_single_item(item)
    if not item or not item.id or not item.user_id or not item.item_id then
        return false, "Invalid parameters"
    end

    local ok = db_util.execute(sql.INSERT_SINGLE_ITEM, {
        id = item.id,
        user_id = item.user_id,
        item_id = item.item_id,
        count = item.count,
        bag_type = item.bag_type or 1,  -- 默认主背包
        slot_index = item.slot_index or 0, -- 默认0号位
        create_time = item.create_time or os.time(),
        update_time = item.update_time or os.time()
    })

    if not ok then
        logger.error("Failed to add single item for user: %d, item_id: %d",
            item.user_id, item.item_id)
        return false, "Database error"
    end

    logger.info("Successfully added single item for user %d, item_id %d, id %d",
        item.user_id, item.item_id, item.id)
    return true
end

return M 