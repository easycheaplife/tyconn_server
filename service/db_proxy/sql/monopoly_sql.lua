local M = {}

-- 获取用户大富翁状态
M.GET_USER_MONOPOLY_STATE = [[
    SELECT 
        id,
        user_id,
        chapter_id,
        current_position,
        direction,
        create_time,
        update_time
    FROM user_monopoly_state 
    WHERE user_id = %d
]]

-- 创建用户大富翁状态
M.CREATE_MONOPOLY_STATE = [[
    INSERT INTO user_monopoly_state (
        user_id, chapter_id, current_position, direction, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d
    )
]]

-- 更新用户大富翁状态
M.UPDATE_MONOPOLY_STATE = [[
    UPDATE user_monopoly_state SET
        chapter_id = %d,
        current_position = %d,
        direction = %d,
        update_time = %d
    WHERE user_id = %d
]]

-- 获取用户章节进度
M.GET_CHAPTER_PROGRESS = [[
    SELECT 
        id,
        user_id,
        chapter_id,
        is_passed,
        pass_time,
        reward_claimed,
        reward_time,
        create_time,
        update_time
    FROM user_chapter_progress 
    WHERE user_id = %d AND chapter_id = %d
]]

-- 创建用户章节进度
M.CREATE_CHAPTER_PROGRESS = [[
    INSERT INTO user_chapter_progress (
        user_id, chapter_id, is_passed, pass_time, reward_claimed, reward_time, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d, %d, %d
    )
]]

-- 更新用户章节进度
M.UPDATE_CHAPTER_PROGRESS = [[
    UPDATE user_chapter_progress SET
        is_passed = %d,
        pass_time = %d,
        reward_claimed = %d,
        reward_time = %d,
        update_time = %d
    WHERE user_id = %d AND chapter_id = %d
]]

-- 获取大富翁事件
M.GET_MONOPOLY_EVENTS = [[
    SELECT 
        id,
        event_id,
        chapter_id,
        cell_id,
        event_type,
        item_id,
        count,
        currency_type,
        amount,
        target_position,
        status,
        create_time,
        update_time
    FROM monopoly_events 
    WHERE chapter_id = %d AND cell_id = %d
]]

-- 获取单个大富翁事件
M.GET_MONOPOLY_EVENT = [[
    SELECT 
        id,
        event_id,
        chapter_id,
        cell_id,
        event_type,
        item_id,
        count,
        currency_type,
        amount,
        target_position,
        status,
        create_time,
        update_time
    FROM monopoly_events 
    WHERE id = %d
]]

-- 创建大富翁事件
M.CREATE_MONOPOLY_EVENT = [[
    INSERT INTO monopoly_events (
        event_id, chapter_id, cell_id, event_type, item_id, count,
        currency_type, amount, target_position, status, create_time, update_time
    ) VALUES (
        '%s', %d, %d, '%s', %d, %d,
        %d, %d, %d, %d, %d, %d
    )
]]

-- 更新大富翁事件状态
M.UPDATE_MONOPOLY_EVENT_STATUS = [[
    UPDATE monopoly_events SET
        status = %d,
        update_time = %d
    WHERE id = %d
]]

-- 记录大富翁操作日志
M.CREATE_MONOPOLY_LOG = [[
    INSERT INTO monopoly_logs (
        user_id, chapter_id, operation_type, dice_value, from_position, to_position,
        event_id, reward_items, operation_time, create_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d,
        %d, '%s', %d, %d
    )
]]

return M 