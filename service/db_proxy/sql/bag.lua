local M = {}

-- 获取用户背包
M.GET_USER_BAG = [[
    SELECT 
        id,
        user_id,
        bag_type,
        size,
        create_time,
        update_time
    FROM user_bags 
    WHERE user_id = %d AND bag_type = %d
]]

-- 获取背包格子
M.GET_BAG_SLOTS = [[
    SELECT 
        id,
        user_id,
        bag_type,
        slot_index,
        state,
        update_time
    FROM bag_slots
    WHERE user_id = %d AND bag_type = %d
    ORDER BY slot_index
]]

-- 创建用户背包
M.CREATE_USER_BAG = [[
    INSERT INTO user_bags (
        id,
        user_id,
        bag_type,
        size,
        create_time,
        update_time
    ) VALUES (
        %d,
        %d,
        %d,
        %d,
        %d,
        %d
    )
]]

-- 创建背包格子
M.CREATE_BAG_SLOT = [[
    INSERT INTO bag_slots (
        id,
        user_id,
        bag_type,
        slot_index,
        state,
        create_time,
        update_time
    ) VALUES (
        %d,
        %d,
        %d,
        %d,
        %d,
        %d,
        %d
    )
]]

-- 删除背包格子
M.DELETE_BAG_SLOTS = [[
    DELETE FROM bag_slots 
    WHERE user_id = %d AND bag_type = %d
]]

-- 删除用户背包
M.DELETE_USER_BAG = [[
    DELETE FROM user_bags 
    WHERE user_id = %d AND bag_type = %d
]]

-- 更新格子状态
M.UPDATE_SLOT_STATE = [[
    UPDATE bag_slots 
    SET state = %d, update_time = %d
    WHERE user_id = %d AND bag_type = %d AND slot_index = %d
]]

-- 更新背包大小
M.UPDATE_BAG_SIZE = [[
    UPDATE user_bags 
    SET size = %d, update_time = %d
    WHERE user_id = %d AND bag_type = %d
]]

return M 