local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local cache = require "cache"
local db_client = require "game.db_client"
local map_model = require "game.models.map_model"
local table_service = require "game.services.table_service"
local json = require "cjson"

local M = {}

-- 获取用户的大富翁状态信息
function M.get_user_map_info(user_id)
    if not user_id then
        logger.error("map_dao.get_user_map_info: invalid user_id")
        return nil
    end
    
    -- 从缓存获取
    local cached_data = cache.get_user_map_info(user_id)
    if cached_data then
        logger.debug("map_dao.get_user_map_info: cache hit for user %d", user_id)
        return cached_data
    end
    
    -- 从数据库获取
    local db_data = db_client.get_user_monopoly_state(user_id)
    if not db_data then
        logger.debug("map_dao.get_user_map_info: no map info found for user %d", user_id)
        return nil
    end
    
    -- 转换为应用模型
    local map_info = map_model.db_to_model(db_data)
    if not map_info then
        logger.error("map_dao.get_user_map_info: failed to convert db data to model for user %d", user_id)
        return nil
    end
    
    -- 缓存数据
    cache.set_user_map_info(user_id, map_info)
    
    return map_info
end

-- 创建用户大富翁状态
function M.create_map_info(map_info)
    if not map_info then
        logger.error("map_dao.create_map_info: map_info is nil")
        return false
    end
    
    -- 验证数据
    local ok, err = map_model.validate(map_info)
    if not ok then
        logger.error("map_dao.create_map_info: invalid map_info, %s", err)
        return false
    end
    
    -- 创建数据库记录
    local result = db_client.create_monopoly_state(map_info)
    if not result then
        logger.error("map_dao.create_map_info: failed to create monopoly state for user %d", map_info.user_id)
        return false
    end
    
    -- 清除可能存在的缓存
    cache.remove_user_map_info(map_info.user_id)
    
    return true
end

-- 更新用户大富翁状态
function M.update_map_info(map_info)
    if not map_info then
        logger.error("map_dao.update_map_info: map_info is nil")
        return false
    end
    
    -- 验证数据
    local ok, err = map_model.validate(map_info)
    if not ok then
        logger.error("map_dao.update_map_info: invalid map_info, %s", err)
        return false
    end
    
    -- 更新数据库记录
    local result = db_client.update_monopoly_state(map_info)
    if not result then
        logger.error("map_dao.update_map_info: failed to update monopoly state for user %d", map_info.user_id)
        return false
    end
    
    -- 更新缓存
    cache.set_user_map_info(map_info.user_id, map_info)
    
    return true
end

-- 获取章节进度
function M.get_chapter_progress(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("map_dao.get_chapter_progress: invalid parameters, user_id=%s, chapter_id=%s", 
            tostring(user_id), tostring(chapter_id))
        return nil
    end
    
    -- 从缓存获取
    local cached_data = cache.get_chapter_progress(user_id, chapter_id)
    if cached_data then
        logger.debug("map_dao.get_chapter_progress: cache hit for user %d, chapter %d", user_id, chapter_id)
        return cached_data
    end
    
    -- 从数据库获取
    local db_data = db_client.get_chapter_progress(user_id, chapter_id)
    if not db_data then
        logger.debug("map_dao.get_chapter_progress: no progress found for user %d, chapter %d", user_id, chapter_id)
        return nil
    end
    
    -- 转换为应用模型
    local progress = map_model.db_to_chapter_progress(db_data)
    if not progress then
        logger.error("map_dao.get_chapter_progress: failed to convert db data to model")
        return nil
    end
    
    -- 缓存数据
    cache.set_chapter_progress(user_id, chapter_id, progress)
    
    return progress
end

-- 创建章节进度
function M.create_chapter_progress(progress_data)
    if not progress_data then
        logger.error("map_dao.create_chapter_progress: progress_data is nil")
        return false
    end
    
    -- 验证数据
    local ok, err = map_model.validate_chapter_progress(progress_data)
    if not ok then
        logger.error("map_dao.create_chapter_progress: invalid progress_data, %s", err)
        return false
    end
    
    -- 创建数据库记录
    local result = db_client.create_chapter_progress(progress_data)
    if not result then
        logger.error("map_dao.create_chapter_progress: failed to create chapter progress for user %d, chapter %d", 
            progress_data.user_id, progress_data.chapter_id)
        return false
    end
    
    -- 清除可能存在的缓存
    cache.remove_chapter_progress(progress_data.user_id, progress_data.chapter_id)
    
    return true
end

-- 更新章节进度
function M.update_chapter_progress(progress_data)
    if not progress_data then
        logger.error("map_dao.update_chapter_progress: progress_data is nil")
        return false
    end
    
    -- 验证数据
    local ok, err = map_model.validate_chapter_progress(progress_data)
    if not ok then
        logger.error("map_dao.update_chapter_progress: invalid progress_data, %s", err)
        return false
    end
    
    -- 更新数据库记录
    local result = db_client.update_chapter_progress(progress_data)
    if not result then
        logger.error("map_dao.update_chapter_progress: failed to update chapter progress for user %d, chapter %d", 
            progress_data.user_id, progress_data.chapter_id)
        return false
    end
    
    -- 更新缓存
    cache.set_chapter_progress(progress_data.user_id, progress_data.chapter_id, progress_data)
    
    return true
end

-- 记录大富翁操作日志
function M.log_monopoly_operation(log_data)
    if not log_data then
        logger.error("map_dao.log_monopoly_operation: log_data is nil")
        return false
    end
    
    -- 验证数据
    local ok, err = map_model.validate_log(log_data)
    if not ok then
        logger.error("map_dao.log_monopoly_operation: invalid log_data, %s", err)
        return false
    end
    
    -- 对奖励物品数据做特殊处理
    if log_data.operation_type == 3 and log_data.reward_items then
        if type(log_data.reward_items) ~= "string" then
            -- 如果不是字符串，需要转换为JSON
            log_data.reward_items = json.encode(log_data.reward_items)
        end
    end
    
    -- 创建数据库记录
    local result = db_client.create_monopoly_log(log_data)
    if not result then
        logger.error("map_dao.log_monopoly_operation: failed to create monopoly log for user %d", log_data.user_id)
        return false
    end
    
    return true
end

-- 创建大富翁事件
function M.create_monopoly_event(event_data)
    if not event_data then
        logger.error("Invalid event data")
        return false, "Invalid event data"
    end
    
    -- 调用数据库代理创建事件
    local ok, result = pcall(function()
        return db_client.create_monopoly_event(event_data)
    end)
    
    if not ok then
        logger.error("Failed to create monopoly event: %s", tostring(result))
        return false, result
    end
    
    -- 清除相关缓存
    cache.remove_map_events(event_data.chapter_id, event_data.cell_id)
    
    return true
end

-- 创建随机事件
function M.create_random_event(event_data)
    if not event_data then
        logger.error("map_dao.create_random_event: Invalid event data")
        return false
    end
    
    -- 校验必要字段
    if not event_data.user_id or not event_data.chapter_id or 
       not event_data.event_id or not event_data.cell_id then
        logger.error("map_dao.create_random_event: Missing required fields")
        return false
    end
    
    -- 调用数据库代理创建随机事件
    local ok, result = pcall(function()
        return db_client.create_monopoly_random_event(event_data)
    end)
    
    if not ok then
        logger.error("map_dao.create_random_event: Failed to create random event: %s", tostring(result))
        return false
    end
    
    -- 清除相关缓存
    cache.remove_random_events(event_data.user_id, event_data.chapter_id)
    
    logger.debug("map_dao.create_random_event: Created random event for user %d, chapter %d, cell %d, event %d",
        event_data.user_id, event_data.chapter_id, event_data.cell_id, event_data.event_id)
    
    return true
end

-- 获取特定事件的数量
function M.count_random_events(user_id, chapter_id, event_id)
    if not user_id or not chapter_id or not event_id then
        logger.error("map_dao.count_random_events: Invalid parameters")
        return 0
    end
    
    -- 从缓存获取
    local cached_count = cache.get_random_event_count(user_id, chapter_id, event_id)
    if cached_count then
        return cached_count
    end
    
    -- 从数据库获取
    local count = db_client.count_monopoly_random_events(user_id, chapter_id, event_id)
    
    -- 缓存结果
    cache.set_random_event_count(user_id, chapter_id, event_id, count)
    
    return count or 0
end

-- 获取已被占用的格子
function M.get_occupied_cells(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("map_dao.get_occupied_cells: Invalid parameters")
        return {}
    end
    
    -- 从缓存获取
    local cached_cells = cache.get_occupied_cells(user_id, chapter_id)
    if cached_cells then
        return cached_cells
    end
    
    -- 从数据库获取
    local cells = db_client.get_occupied_cells(user_id, chapter_id)
    if not cells then
        return {}
    end
    
    -- 转换为哈希表格式以便快速查找
    local occupied_cells = {}
    for _, cell in ipairs(cells) do
        occupied_cells[cell.cell_id] = true
    end
    
    -- 缓存结果
    cache.set_occupied_cells(user_id, chapter_id, occupied_cells)
    
    return occupied_cells
end

-- 获取所有随机事件
function M.get_random_events(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("map_dao.get_random_events: Invalid parameters")
        return {}
    end
    
    -- 从缓存获取
    local cached_events = cache.get_random_events(user_id, chapter_id)
    if cached_events then
        return cached_events
    end
    
    -- 从数据库获取
    local events = db_client.get_monopoly_random_events(user_id, chapter_id)
    if not events then
        return {}
    end
    
    -- 缓存结果
    cache.set_random_events(user_id, chapter_id, events)
    
    return events
end

-- 获取格子事件
function M.get_cell_events(params)
    if not params or not params.chapter_id or not params.cell_id then
        logger.error("Invalid parameters")
        return nil
    end

    -- 尝试从缓存获取
    local events = cache.get_map_events(params.chapter_id, params.cell_id)
    if events then
        return events
    end

    -- 从数据库获取
    local ok, result = pcall(function()
        return db_client.get_monopoly_events(params)
    end)

    if not ok then
        logger.error("Failed to get monopoly events: %s", tostring(result))
        return nil
    end

    -- 缓存结果
    if result and #result > 0 then
        cache.set_map_events(params.chapter_id, params.cell_id, result)
    end

    return result
end

-- 更新事件状态
function M.update_event_status(event_id, status)
    if not event_id or not status then
        logger.error("Invalid parameters")
        return false
    end

    local ok, result = pcall(function()
        return db_client.update_monopoly_event_status(event_id, status, os.time())
    end)

    if not ok then
        logger.error("Failed to update event status: %s", tostring(result))
        return false
    end

    return true
end

return M 