local M = {}

-- 查询用户物品列表
M.GET_USER_ITEMS = {
    sql = [[
        SELECT 
            id,
            user_id,
            item_id,
            count,
            create_time,
            update_time
        FROM user_items 
        WHERE user_id = %d
        ORDER BY item_id ASC
    ]],
    params = {"user_id"}
}

-- 批量插入物品
M.INSERT_ITEMS = {
    sql = [[
        INSERT INTO user_items (
            id, user_id, item_id, count,
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

return M 