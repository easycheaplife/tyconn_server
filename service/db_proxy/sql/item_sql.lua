local M = {}

-- 查询用户物品列表
M.GET_USER_ITEMS = {
    sql = [[
        SELECT 
            id,
            user_id,
            item_id,
            count,
            bag_type,
            slot_index,
            create_time,
            update_time
        FROM user_items 
        WHERE user_id = %d
        ORDER BY bag_type, slot_index
    ]],
    params = {"user_id"}
}

-- 批量插入物品
M.INSERT_ITEMS = {
    sql = [[
        INSERT INTO user_items (
            id, user_id, item_id, count, bag_type, slot_index,
            create_time, update_time
        ) VALUES %s
    ]],
    params = {"values"}
}

-- 删除用户物品
M.DELETE_USER_ITEMS = {
    sql = [[
        DELETE FROM user_items 
        WHERE user_id = %d
    ]],
    params = {"user_id"}
}

-- 记录物品变化
M.LOG_ITEM_CHANGE = {
    sql = [[
        INSERT INTO item_logs (
            user_id, item_id, count,
            type, source, before_count,
            after_count, create_time
        ) VALUES (
            %d, %d, %d,
            %d, '%s', %d,
            %d, %d
        )
    ]],
    params = {
        "user_id", "item_id", "count",
        "type", "source", "before_count",
        "after_count", "create_time"
    }
}

-- 更新单个物品
M.UPDATE_SINGLE_ITEM = {
    sql = [[
        UPDATE user_items 
        SET 
            count = %d,
            bag_type = %d,
            slot_index = %d,
            update_time = %d
        WHERE 
            id = %d AND user_id = %d
    ]],
    params = {
        "count", "bag_type", "slot_index", "update_time", 
        "id", "user_id"
    }
}

-- 插入单个物品
M.INSERT_SINGLE_ITEM = {
    sql = [[
        INSERT INTO user_items (
            id, user_id, item_id, 
            count, bag_type, slot_index,
            create_time, update_time
        ) VALUES (
            %d, %d, %d, 
            %d, %d, %d,
            %d, %d
        )
    ]],
    params = {
        "id", "user_id", "item_id", 
        "count", "bag_type", "slot_index",
        "create_time", "update_time"
    }
}

return M 