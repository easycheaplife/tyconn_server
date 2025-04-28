local skynet = require "skynet"
local utils = require "utils"
local logger = require "logger"
local json = require "cjson"

local M = {}

-- 创建新的用户大富翁状态
function M.new(params)
    if not params or not params.user_id or not params.chapter_id then
        logger.error("Invalid parameters for creating monopoly state")
        return nil
    end
    
    return {
        id = params.id, -- 数据库自增ID
        user_id = params.user_id,
        chapter_id = params.chapter_id,
        current_position = params.current_position or 0,
        direction = params.direction or 1, -- 1:正向, -1:反向
        create_time = params.create_time or os.time(),
        update_time = params.update_time or os.time()
    }
end

-- 将数据库中的大富翁状态数据转换为应用模型
function M.db_to_model(db_data)
    if not db_data then
        return nil
    end
    
    return {
        id = db_data.id,
        user_id = db_data.user_id,
        chapter_id = db_data.chapter_id,
        current_position = db_data.current_position,
        direction = db_data.direction,
        create_time = db_data.create_time,
        update_time = db_data.update_time
    }
end

-- 验证大富翁状态数据是否有效
function M.validate(map_data)
    if not map_data then
        return false, "Map data is nil"
    end
    
    if not map_data.user_id then
        return false, "Missing user_id"
    end
    
    if not map_data.chapter_id then
        return false, "Missing chapter_id"
    end
    
    -- 验证位置是否合法
    if map_data.current_position == nil or map_data.current_position < 0 then
        return false, "Invalid current_position"
    end
    
    -- 验证方向是否合法
    if map_data.direction == nil or (map_data.direction ~= 1 and map_data.direction ~= -1) then
        return false, "Invalid direction"
    end
    
    return true
end

-- 创建新的章节进度
function M.new_chapter_progress(params)
    if not params or not params.user_id or not params.chapter_id then
        logger.error("Invalid parameters for creating chapter progress")
        return nil
    end
    
    return {
        id = params.id, -- 数据库自增ID
        user_id = params.user_id,
        chapter_id = params.chapter_id,
        is_passed = params.is_passed or 0, -- 0:未通过, 1:已通过
        pass_time = params.pass_time,
        reward_claimed = params.reward_claimed or 0, -- 0:未领取, 1:已领取
        reward_time = params.reward_time,
        create_time = params.create_time or os.time(),
        update_time = params.update_time or os.time()
    }
end

-- 将数据库中的章节进度数据转换为应用模型
function M.db_to_chapter_progress(db_data)
    if not db_data then
        return nil
    end
    
    return {
        id = db_data.id,
        user_id = db_data.user_id,
        chapter_id = db_data.chapter_id,
        is_passed = db_data.is_passed,
        pass_time = db_data.pass_time,
        reward_claimed = db_data.reward_claimed,
        reward_time = db_data.reward_time,
        create_time = db_data.create_time,
        update_time = db_data.update_time
    }
end

-- 验证章节进度数据是否有效
function M.validate_chapter_progress(progress_data)
    if not progress_data then
        return false, "Progress data is nil"
    end
    
    if not progress_data.user_id then
        return false, "Missing user_id"
    end
    
    if not progress_data.chapter_id then
        return false, "Missing chapter_id"
    end
    
    return true
end

-- 创建新的事件
function M.new_event(params)
    if not params or not params.chapter_id or not params.cell_id then
        logger.error("Invalid parameters for creating monopoly event")
        return nil
    end
    
    return {
        id = params.id, -- 数据库自增ID
        event_id = params.event_id or utils.gen_guid(), -- 事件唯一ID
        chapter_id = params.chapter_id,
        cell_id = params.cell_id,
        event_type = params.event_type or "item", -- 事件类型: item, currency, teleport等
        item_id = params.item_id,
        count = params.count,
        currency_type = params.currency_type,
        amount = params.amount,
        target_position = params.target_position,
        status = params.status or 0, -- 0:未处理, 1:处理中, 2:已处理
        create_time = params.create_time or os.time(),
        update_time = params.update_time or os.time()
    }
end

-- 将数据库中的事件数据转换为应用模型
function M.db_to_event(db_data)
    if not db_data then
        return nil
    end
    
    return {
        id = db_data.id,
        event_id = db_data.event_id,
        chapter_id = db_data.chapter_id,
        cell_id = db_data.cell_id,
        event_type = db_data.event_type,
        item_id = db_data.item_id,
        count = db_data.count,
        currency_type = db_data.currency_type,
        amount = db_data.amount,
        target_position = db_data.target_position,
        status = db_data.status,
        create_time = db_data.create_time,
        update_time = db_data.update_time
    }
end

-- 验证事件数据是否有效
function M.validate_event(event_data)
    if not event_data then
        return false, "Event data is nil"
    end
    
    if not event_data.chapter_id then
        return false, "Missing chapter_id"
    end
    
    if not event_data.cell_id then
        return false, "Missing cell_id"
    end
    
    if not event_data.event_type then
        return false, "Missing event_type"
    end
    
    return true
end

-- 创建新的操作日志
function M.new_log(params)
    if not params or not params.user_id or not params.chapter_id or not params.operation_type then
        logger.error("Invalid parameters for creating monopoly log")
        return nil
    end
    
    local log_data = {
        id = params.id, -- 数据库自增ID
        user_id = params.user_id,
        chapter_id = params.chapter_id,
        operation_type = params.operation_type,
        operation_time = params.operation_time or os.time(),
        create_time = params.create_time or os.time()
    }
    
    -- 添加特定操作类型的数据
    if params.operation_type == 1 then -- 掷骰子
        log_data.dice_value = params.dice_value
        log_data.from_position = params.from_position
        log_data.to_position = params.to_position
    elseif params.operation_type == 2 then -- 处理事件
        log_data.event_id = params.event_id
    elseif params.operation_type == 3 then -- 领取奖励
        -- 将物品数据转为JSON存储
        if params.reward_items then
            log_data.reward_items = json.encode(params.reward_items)
        end
    end
    
    return log_data
end

-- 将数据库中的日志数据转换为应用模型
function M.db_to_log(db_data)
    if not db_data then
        return nil
    end
    
    local log = {
        id = db_data.id,
        user_id = db_data.user_id,
        chapter_id = db_data.chapter_id,
        operation_type = db_data.operation_type,
        operation_time = db_data.operation_time,
        create_time = db_data.create_time
    }
    
    -- 解析特定操作类型的数据
    if db_data.operation_type == 1 then -- 掷骰子
        log.dice_value = db_data.dice_value
        log.from_position = db_data.from_position
        log.to_position = db_data.to_position
    elseif db_data.operation_type == 2 then -- 处理事件
        log.event_id = db_data.event_id
    elseif db_data.operation_type == 3 then -- 领取奖励
        -- 将JSON数据转为表格
        if db_data.reward_items then
            local success, items = pcall(json.decode, db_data.reward_items)
            if success then
                log.reward_items = items
            else
                log.reward_items = {}
                logger.error("Failed to decode reward_items JSON: %s", db_data.reward_items)
            end
        else
            log.reward_items = {}
        end
    end
    
    return log
end

-- 验证日志数据是否有效
function M.validate_log(log_data)
    if not log_data then
        return false, "Log data is nil"
    end
    
    if not log_data.user_id then
        return false, "Missing user_id"
    end
    
    if not log_data.chapter_id then
        return false, "Missing chapter_id"
    end
    
    if not log_data.operation_type then
        return false, "Missing operation_type"
    end
    
    if not log_data.operation_time then
        return false, "Missing operation_time"
    end
    
    return true
end

return M
