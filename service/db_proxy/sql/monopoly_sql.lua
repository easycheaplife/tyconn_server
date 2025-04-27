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
        user_id,
        chapter_id,
        event_id,
        cell_id,
        status,
        is_random_event,
        trigger_time,
        complete_time
    FROM monopoly_events 
    WHERE chapter_id = %d AND cell_id = %d
]]

-- 获取单个大富翁事件
M.GET_MONOPOLY_EVENT = [[
    SELECT 
        id,
        user_id,
        chapter_id,
        event_id,
        cell_id,
        status,
        is_random_event,
        trigger_time,
        complete_time
    FROM monopoly_events 
    WHERE id = %d
]]

-- 创建大富翁事件
M.CREATE_MONOPOLY_EVENT = [[
    INSERT INTO monopoly_events (
        user_id,
        chapter_id,
        event_id,
        cell_id,
        status,
        is_random_event,
        trigger_time,
        complete_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d, %d, %d
    )
]]

-- 更新大富翁事件状态
M.UPDATE_MONOPOLY_EVENT_STATUS = [[
    UPDATE monopoly_events SET
        status = %d,
        complete_time = %d
    WHERE id = %d
]]

-- 记录大富翁操作日志
M.CREATE_MONOPOLY_LOG = [[
    INSERT INTO monopoly_logs (
        user_id,
        chapter_id,
        operation_type,
        dice_value,
        from_position,
        to_position,
        event_id,
        reward_items,
        operation_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d,
        %d, '%s', %d
    )
]]

-- 创建随机事件
M.CREATE_MONOPOLY_RANDOM_EVENT = [[
    INSERT INTO monopoly_random_events (
        user_id,
        chapter_id,
        event_id,
        cell_id,
        create_time,
        update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d
    )
]]

-- 统计随机事件数量
M.COUNT_MONOPOLY_RANDOM_EVENTS = [[
    SELECT 
        COUNT(*) as count
    FROM monopoly_random_events 
    WHERE user_id = %d AND chapter_id = %d AND event_id = %d
]]

-- 获取已占用的格子
M.GET_OCCUPIED_CELLS = [[
    SELECT 
        cell_id
    FROM monopoly_random_events 
    WHERE user_id = %d AND chapter_id = %d
]]

-- 获取用户随机事件列表
M.GET_MONOPOLY_RANDOM_EVENTS = [[
    SELECT 
        id,
        user_id,
        chapter_id,
        event_id,
        cell_id,
        create_time,
        update_time
    FROM monopoly_random_events 
    WHERE user_id = %d AND chapter_id = %d
]]

-- 获取用户通过的章节
M.GET_USER_PASSED_CHAPTERS = [[
    SELECT 
        chapter_id
    FROM user_chapter_progress   
    WHERE user_id = %d
]]

-- 获取事件触发次数
M.GET_EVENT_TRIGGER_COUNT = [[
    SELECT id, user_id, chapter_id, 
        event_id, 
        trigger_count, create_time, update_time
    FROM monopoly_event_triggers
    WHERE user_id = %d AND chapter_id = %d AND event_id = %d
    LIMIT 1
]]

-- 获取章节所有事件触发记录
M.GET_CHAPTER_EVENT_TRIGGERS = [[
    SELECT id, user_id, chapter_id, 
        event_id, 
        trigger_count, create_time, update_time
    FROM monopoly_event_triggers
    WHERE user_id = %d AND chapter_id = %d
    ORDER BY event_id ASC
]]

-- 创建事件触发记录
M.CREATE_EVENT_TRIGGER = [[
    INSERT INTO monopoly_event_triggers (
        user_id, chapter_id, 
        event_id, 
        trigger_count, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d
    )
]]

-- 更新事件触发次数
M.UPDATE_EVENT_TRIGGER_COUNT = [[
    UPDATE monopoly_event_triggers SET
        trigger_count = %d,
        update_time = %d
    WHERE user_id = %d AND chapter_id = %d AND event_id = %d
]]

-- 增加事件触发次数
M.INCREMENT_EVENT_TRIGGER_COUNT = [[
    UPDATE monopoly_event_triggers
    SET trigger_count = trigger_count + 1, update_time = %d
    WHERE user_id = %d AND chapter_id = %d AND event_id = %d
]]

return M 