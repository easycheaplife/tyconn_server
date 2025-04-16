local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.monopoly_sql"
local db_util = require "db_proxy.utils.db_util"
local utils = require "utils"

local M = {}

-- 获取用户大富翁状态
function M.get_user_monopoly_state(user_id)
    if not user_id then
        return nil, "Invalid user id"
    end
    
    local query = string.format(sql.GET_USER_MONOPOLY_STATE, user_id)
    local results = db_util.query(query)
    
    if not results then
        logger.error("Failed to get monopoly state for user: %d", user_id)
        return nil, "Database error"
    end
    
    if #results == 0 then
        return nil, "record not found"
    end
    
    return results[1]
end

-- 创建用户大富翁状态
function M.create_monopoly_state(state_data)
    if not state_data or not state_data.user_id then
        return false, "Invalid state data"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        user_id = state_data.user_id,
        chapter_id = state_data.chapter_id or 1,
        current_position = state_data.current_position or 0,
        direction = state_data.direction or 1,
        create_time = state_data.create_time or os.time(),
        update_time = state_data.update_time or os.time()
    }
    
    local query = string.format(sql.CREATE_MONOPOLY_STATE,
        data.user_id,
        data.chapter_id,
        data.current_position,
        data.direction,
        data.create_time,
        data.update_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create monopoly state for user: %d", data.user_id)
        return false, "Database error"
    end
    
    return true
end

-- 更新用户大富翁状态
function M.update_monopoly_state(state_data)
    if not state_data or not state_data.user_id then
        return false, "Invalid state data"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        user_id = state_data.user_id,
        chapter_id = state_data.chapter_id,
        current_position = state_data.current_position,
        direction = state_data.direction,
        update_time = state_data.update_time or os.time()
    }
    
    local query = string.format(sql.UPDATE_MONOPOLY_STATE,
        data.chapter_id,
        data.current_position,
        data.direction,
        data.update_time,
        data.user_id
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to update monopoly state for user: %d", data.user_id)
        return false, "Database error"
    end
    
    return true
end

-- 获取用户章节进度
function M.get_chapter_progress(params)
    if not params or not params.user_id or not params.chapter_id then
        return nil, "Invalid parameters"
    end
    
    local query = string.format(sql.GET_CHAPTER_PROGRESS, params.user_id, params.chapter_id)
    local results = db_util.query(query)
    
    if not results then
        logger.error("Failed to get chapter progress for user: %d, chapter: %d", 
            params.user_id, params.chapter_id)
        return nil, "Database error"
    end
    
    if #results == 0 then
        return nil, "record not found"
    end
    
    return results[1]
end

-- 创建用户章节进度
function M.create_chapter_progress(progress_data)
    if not progress_data or not progress_data.user_id or not progress_data.chapter_id then
        return false, "Invalid progress data"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        user_id = progress_data.user_id,
        chapter_id = progress_data.chapter_id,
        is_passed = progress_data.is_passed or 0,
        pass_time = progress_data.pass_time or 0,
        reward_claimed = progress_data.reward_claimed or 0,
        reward_time = progress_data.reward_time or 0,
        create_time = progress_data.create_time or os.time(),
        update_time = progress_data.update_time or os.time()
    }
    
    local query = string.format(sql.CREATE_CHAPTER_PROGRESS,
        data.user_id,
        data.chapter_id,
        data.is_passed,
        data.pass_time,
        data.reward_claimed,
        data.reward_time,
        data.create_time,
        data.update_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create chapter progress for user: %d, chapter: %d", 
            data.user_id, data.chapter_id)
        return false, "Database error"
    end
    
    return true
end

-- 更新用户章节进度
function M.update_chapter_progress(progress_data)
    if not progress_data or not progress_data.user_id or not progress_data.chapter_id then
        return false, "Invalid progress data"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        user_id = progress_data.user_id,
        chapter_id = progress_data.chapter_id,
        is_passed = progress_data.is_passed or 0,
        pass_time = progress_data.pass_time or os.time(),
        reward_claimed = progress_data.reward_claimed or 0,
        reward_time = progress_data.reward_time or os.time(),
        update_time = progress_data.update_time or os.time()
    }
    
    logger.info("update_chapter_progress: %s", utils.table_to_string(data))
    
    local query = string.format(sql.UPDATE_CHAPTER_PROGRESS,
        data.is_passed,
        data.pass_time,
        data.reward_claimed,
        data.reward_time,
        data.update_time,
        data.user_id,
        data.chapter_id
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to update chapter progress for user: %d, chapter: %d", 
            data.user_id, data.chapter_id)
        return false, "Database error"
    end
    
    return true
end

-- 获取大富翁事件
function M.get_monopoly_events(params)
    if not params or not params.chapter_id or not params.cell_id then
        return nil, "Invalid parameters"
    end
    
    local query = string.format(sql.GET_MONOPOLY_EVENTS, params.chapter_id, params.cell_id)
    
    -- 添加状态过滤条件
    if params.status ~= nil then
        query = query .. string.format(" AND status = %d", params.status)
    end
    
    -- 添加排序
    query = query .. " ORDER BY id ASC"
    
    local results = db_util.query(query)
    
    if not results then
        logger.error("Failed to get monopoly events for chapter: %d, cell: %d", 
            params.chapter_id, params.cell_id)
        return nil, "Database error"
    end
    
    return results
end

-- 获取单个大富翁事件
function M.get_monopoly_event(event_id)
    if not event_id then
        return nil, "Invalid event id"
    end
    
    local query = string.format(sql.GET_MONOPOLY_EVENT, event_id)
    local results = db_util.query(query)
    
    if not results then
        logger.error("Failed to get monopoly event: %d", event_id)
        return nil, "Database error"
    end
    
    if #results == 0 then
        return nil, "Event not found"
    end
    
    return results[1]
end

-- 创建大富翁事件记录
function M.create_monopoly_event(data)
    if not data or not data.user_id or not data.chapter_id or not data.cell_id or not data.event_id then
        logger.error("Invalid event data: %s", utils.table_to_string(data))
        return false, "Invalid event data"
    end
    
    -- 确保所有字段都有合适的默认值
    local event_data = {
        user_id = data.user_id,
        chapter_id = data.chapter_id,
        cell_id = data.cell_id,
        event_id = data.event_id,
        status = data.status or 0,
        is_random_event = data.is_random_event or 0,
        trigger_time = data.trigger_time or os.time(),
        complete_time = data.complete_time or 0
    }
    
    local query = string.format(sql.CREATE_MONOPOLY_EVENT,
        event_data.user_id,
        event_data.chapter_id,
        event_data.event_id,
        event_data.cell_id,
        event_data.status,
        event_data.is_random_event,
        event_data.trigger_time,
        event_data.complete_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create monopoly event for chapter: %d, cell: %d", 
            event_data.chapter_id, event_data.cell_id)
        return false, "Database error"
    end
    
    return true
end

-- 更新大富翁事件状态
function M.update_monopoly_event_status(params)
    if not params or not params.id then
        return false, "Invalid parameters"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        id = params.id,
        status = params.status or 0,
        update_time = params.update_time or os.time()
    }
    
    local query = string.format(sql.UPDATE_MONOPOLY_EVENT_STATUS,
        data.status,
        data.update_time,
        data.id
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to update monopoly event status: %d", data.id)
        return false, "Database error"
    end
    
    return true
end

-- 记录大富翁操作日志
function M.create_monopoly_log(log_data)
    if not log_data or not log_data.user_id or not log_data.chapter_id or not log_data.operation_type then
        return false, "Invalid log data"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        user_id = log_data.user_id,
        chapter_id = log_data.chapter_id,
        operation_type = log_data.operation_type,
        dice_value = log_data.dice_value or 0,
        from_position = log_data.from_position or 0,
        to_position = log_data.to_position or 0,
        event_id = log_data.event_id or 0,
        reward_items = log_data.reward_items or "[]",
        operation_time = log_data.operation_time or os.time()
    }
    
    -- 处理 reward_items，确保是字符串
    if type(data.reward_items) == "table" then
        data.reward_items = utils.encode_json(data.reward_items)
    end
    
    -- 使用 db_util.escape_string 来安全处理 JSON 字符串
    local reward_items_escaped = db_util.escape_string(data.reward_items)
    
    local query = string.format(sql.CREATE_MONOPOLY_LOG,
        data.user_id,
        data.chapter_id,
        data.operation_type,
        data.dice_value,
        data.from_position,
        data.to_position,
        data.event_id,
        reward_items_escaped,
        data.operation_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create monopoly log for user: %d, operation_type: %d", 
            data.user_id, data.operation_type)
        return false, "Database error"
    end
    
    return true
end

-- 创建随机事件
function M.create_monopoly_random_event(event_data)
    if not event_data or not event_data.user_id or not event_data.chapter_id 
        or not event_data.event_id or not event_data.cell_id then
        logger.error("Invalid random event data: %s", utils.table_to_string(event_data))
        return false, "Invalid random event data"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        user_id = event_data.user_id,
        chapter_id = event_data.chapter_id,
        event_id = event_data.event_id,
        cell_id = event_data.cell_id,
        create_time = event_data.create_time or os.time(),
        update_time = event_data.update_time or os.time()
    }
    
    local query = string.format(sql.CREATE_MONOPOLY_RANDOM_EVENT,
        data.user_id,
        data.chapter_id,
        data.event_id,
        data.cell_id,
        data.create_time,
        data.update_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create random event for user: %d, chapter: %d, event: %d", 
            data.user_id, data.chapter_id, data.event_id)
        return false, "Database error"
    end
    
    return true
end

-- 统计随机事件数量
function M.count_monopoly_random_events(user_id, chapter_id, event_id)
    if not user_id or not chapter_id or not event_id then
        logger.error("Invalid parameters for count_monopoly_random_events")
        return 0
    end
    
    local query = string.format(sql.COUNT_MONOPOLY_RANDOM_EVENTS,
        user_id, chapter_id, event_id)
    
    local results = db_util.query(query)
    if not results or #results == 0 then
        logger.warn("No results found for count_monopoly_random_events")
        return 0
    end
    
    return tonumber(results[1].count) or 0
end

-- 获取已占用的格子
function M.get_occupied_cells(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("Invalid parameters for get_occupied_cells")
        return {}
    end
    
    local query = string.format(sql.GET_OCCUPIED_CELLS, user_id, chapter_id)
    
    local results = db_util.query(query)
    if not results then
        logger.error("Failed to get occupied cells for user: %d, chapter: %d", 
            user_id, chapter_id)
        return {}
    end
    
    return results
end

-- 获取用户随机事件
function M.get_monopoly_random_events(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("Invalid parameters for get_monopoly_random_events")
        return {}
    end
    
    local query = string.format(sql.GET_MONOPOLY_RANDOM_EVENTS, 
        user_id, chapter_id)
    
    local results = db_util.query(query)
    if not results then
        logger.error("Failed to get random events for user: %d, chapter: %d", 
            user_id, chapter_id)
        return {}
    end
    
    return results
end

return M 