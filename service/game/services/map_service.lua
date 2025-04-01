local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local map_dao = require "game.dao.map_dao"
local map_model = require "game.models.map_model"
local table_service = require "game.services.table_service"
local bag_service = require "game.services.bag_service"
local error = require "error"
local enum = require "enum"

local M = {}

-- 操作类型常量
local OPERATION_TYPE = {
    ROLL_DICE = 1,     -- 掷骰子
    HANDLE_EVENT = 2,  -- 处理事件
    CLAIM_REWARD = 3   -- 领取奖励
}

-- 事件处理器模块
local event_handlers = {}

-- 处理物品奖励事件
function event_handlers.handle_item_reward(user_id, event)
    local bags = {}
    local success = true
    
    -- 从事件数据中获取物品信息
    if event.cell_events and #event.cell_events > 0 then
        local event_data = event.cell_events[1]
        if #event_data >= 3 then
            local item_id = event_data[2]
            local count = event_data[3]
            
            local ok, result = bag_service.add_item(user_id, item_id, count, enum.ChangeSource.SOURCE_REWARD)
            if ok and result then
                bags = result
            else
                success = false
                logger.error("Failed to add item for user %d, item %d, count %d", 
                    user_id, item_id, count)
            end
        else
            success = false
            logger.error("Invalid item reward event data format")
        end
    else
        success = false
        logger.error("Invalid item reward event data: missing cell_events")
    end
    
    return success, bags, nil
end

-- 处理传送事件
function event_handlers.handle_teleport(user_id, event, map_info)
    local success = true
    local new_position = nil
    
    -- 从事件数据中获取目标位置
    if event.cell_events and #event.cell_events > 0 then
        local event_data = event.cell_events[1]
        if #event_data >= 2 then
            new_position = event_data[2]
            
            -- 更新角色位置
            map_info.current_position = new_position
            map_info.update_time = os.time()
            
            local ok = map_dao.update_map_info(map_info)
            if not ok then
                success = false
                logger.error("Failed to update position for user %d to position %d", 
                    user_id, new_position)
            end
        else
            success = false
            logger.error("Invalid teleport event data format")
        end
    else
        success = false
        logger.error("Invalid teleport event data: missing cell_events")
    end
    
    return success, nil, new_position
end

-- 处理转向事件
function event_handlers.handle_direction_change(user_id, event, map_info)
    local success = true
    
    -- 从事件数据中获取方向
    if event.cell_events and #event.cell_events > 0 then
        local event_data = event.cell_events[1]
        if #event_data >= 2 then
            local direction = event_data[2]
            
            -- 更新角色方向
            map_info.direction = direction
            map_info.update_time = os.time()
            
            local ok = map_dao.update_map_info(map_info)
            if not ok then
                success = false
                logger.error("Failed to update direction for user %d to direction %d", 
                    user_id, direction)
            end
        else
            success = false
            logger.error("Invalid direction change event data format")
        end
    else
        success = false
        logger.error("Invalid direction change event data: missing cell_events")
    end
    
    return success, nil, nil
end

-- 处理一般性事件（不需要特殊处理的事件）
function event_handlers.handle_generic_event(user_id, event)
    logger.info("Handling generic event: user_id=%d, event_id=%d, cell_events=%s", 
        user_id, event.event_id, utils.table_to_string(event.cell_events))
    return true, nil, nil
end

-- 通过章节ID和格子ID获取格子数据
local function get_cell_data_by_chapter(chapter_id, cell_id)
    if not chapter_id or not cell_id then
        logger.error("Invalid parameters: chapter_id=%s, cell_id=%s", 
            tostring(chapter_id), tostring(cell_id))
        return nil
    end

    -- 获取章节配置以获取地图ID
    local chapter_config = M.get_chapter_config(chapter_id)
    if not chapter_config then
        logger.error("Failed to get chapter config for chapter %d", chapter_id)
        return nil
    end

    -- 获取格子数据
    return get_cell_data(chapter_config.map_id, cell_id)
end

-- 事件处理分发函数
local function dispatch_event(user_id, event, map_info)
    local success = false
    local bags = nil
    local new_position = nil
        
    logger.debug("Dispatching event: user_id=%d, event_id=%d", user_id, event.event_id)
    
    -- 获取格子数据
    local cell_data = get_cell_data_by_chapter(event.chapter_id, event.cell_id)
    if not cell_data then
        logger.error("Failed to get cell data for chapter %d, cell %d", 
            event.chapter_id, event.cell_id)
        return false, nil, nil
    end
    
    -- 合并事件配置和事件数据
    local complete_event = {
        event_id = event.event_id,
        cell_events = cell_data.cell_events,
        cell_objects_events = cell_data.cell_objects_events
    }
    
    -- 根据事件类型调用对应的处理函数
    if event.event_id == enum.CellEventType.EVENT_TYPE_ITEM_REWARD then
        success, bags, new_position = event_handlers.handle_item_reward(user_id, complete_event)
    elseif event.event_id == enum.CellEventType.EVENT_TYPE_JUMP then
        success, bags, new_position = event_handlers.handle_teleport(user_id, complete_event, map_info)
    elseif event.event_id == enum.CellEventType.EVENT_TYPE_TURN then
        success, bags, new_position = event_handlers.handle_direction_change(user_id, complete_event, map_info)
    else
        -- 默认处理方式
        success, bags, new_position = event_handlers.handle_generic_event(user_id, complete_event)
    end
    
    return success, bags, new_position
end

-- 获取章节配置
function M.get_chapter_config(chapter_id)
    if not chapter_id then
        logger.error("Invalid chapter_id")
        return nil
    end
    
    -- 从配置获取章节信息
    local configs = table_service.get_config_values("monopoly")
    if not configs then
        logger.error("Failed to get monopoly config for chapter %d", chapter_id)
        return nil
    end
    
    -- 获取特定章节的配置
    local chapter_config = configs[chapter_id]
    if not chapter_config then
        logger.error("Chapter config not found for chapter %d", chapter_id)
        return nil
    end
    -- 获取地图ID (Customs值)
    local map_id = chapter_config.map_id
    
    -- 从cell_data配置中获取该地图的总格子数
    local total_cells = 0
    local cell_configs = table_service.get_config_values("cell_data")
    if cell_configs and cell_configs[map_id] then
        total_cells = #cell_configs[map_id]
    end
    
    -- 转换配置格式
    return {
        id = chapter_id,
        map_id = map_id,
        total_cells = total_cells,
        victory_condition = chapter_config.Victory_condition or {},
        chapter_reward = chapter_config.Reward or {},
        next_chapter = chapter_config.Unlock or 0,
        chapter_difficulty = 1,
        chapter_index = chapter_id,
        chapter_icon = chapter_config.Bg_pic
    }
end

-- 获取用户大富翁状态信息
function M.get_map_info(user_id)
    if not user_id then
        logger.error("Invalid user_id")
        return nil
    end
    
    -- 获取用户大富翁状态
    local map_info = map_dao.get_user_map_info(user_id)
    
    -- 如果没有，则创建新的状态信息
    if not map_info then
        logger.info("Creating new monopoly state for user %d", user_id)
        
        local new_map = map_model.new({
            user_id = user_id,
            chapter_id = 1,  -- 默认从第一章开始
            current_position = 0, -- 初始位置为0
            direction = 1    -- 初始方向（正向）
        })
        
        local ok = map_dao.create_map_info(new_map)
        if not ok then
            logger.error("Failed to create monopoly state for user %d", user_id)
            return nil
        end
        
        map_info = new_map
    end
    
    return map_info
end

-- 获取格子数据
local function get_cell_data(map_id, position)
    if not map_id or not position then
        logger.error("Invalid parameters: map_id=%s, position=%s", 
            tostring(map_id), tostring(position))
        return nil
    end

    local cell_configs = table_service.get_config_values("cell_data")
    if not cell_configs then
        logger.error("Failed to get cell_data config")
        return nil
    end
    if not cell_configs[map_id] then
        logger.error("Failed to get cell_data config for map_id %d", map_id)
        return nil
    end
   
    local cell_data = cell_configs[map_id][position]
    if not cell_data then
        logger.error("Failed to get cell_data config for map_id %d, position %d", map_id, position)
        return nil
    end
    
    logger.debug("cell_data for position %d: %s", position, utils.table_to_string(cell_data))
    return cell_data
end

-- 获取格子事件
local function get_cell_events(cell_data, position)
    if not cell_data then
        return {}
    end

    local event_ids = {}
    
    -- 处理格子事件
    if cell_data.cell_events and #cell_data.cell_events > 0 then
        logger.debug("Found %d cell_events at position %d", #cell_data.cell_events, position)
        for _, event_data in ipairs(cell_data.cell_events) do
            if type(event_data) == "table" and #event_data > 0 then
                table.insert(event_ids, event_data[1])
            end
        end
    end
        
    -- 处理格子对象事件
    if cell_data.cell_objects_events and #cell_data.cell_objects_events > 0 then
        logger.debug("Found %d cell_objects_events at position %d", #cell_data.cell_objects_events, position)
        for _, event_data in ipairs(cell_data.cell_objects_events) do
            if type(event_data) == "table" and #event_data > 0 then
                table.insert(event_ids, event_data[1])
            end
        end
    end
    
    return event_ids
end

-- 掷骰子
function M.roll_dice(user_id)
    if not user_id then
        logger.error("Invalid user_id")
        return nil
    end
    
    -- 获取用户大富翁状态
    local map_info = M.get_map_info(user_id)
    if not map_info then
        logger.error("Failed to get monopoly state for user %d", user_id)
        return nil
    end
    
    -- 生成骰子点数(1-6)
    local dice_value = math.random(1, 6)
    logger.info("User %d rolled dice: %d", user_id, dice_value)
    
    -- 记录起始位置
    local from_position = map_info.current_position
    
    -- 获取章节配置
    local chapter_config = M.get_chapter_config(map_info.chapter_id)
    if not chapter_config then
        logger.error("Failed to get chapter config for chapter %d", map_info.chapter_id)
        return nil
    end
    logger.info("chapter_config: %s", utils.table_to_string(chapter_config))
    -- 计算目标位置
    local to_position = from_position + (dice_value * map_info.direction)
    
    -- 检查边界
    if to_position >= chapter_config.total_cells then
        to_position = chapter_config.total_cells  -- 到达终点
    elseif to_position < 0 then
        to_position = 0  -- 回到起点
    end
    
    -- 更新位置
    map_info.current_position = to_position
    map_info.update_time = os.time()
    
    -- 保存更新
    local ok = map_dao.update_map_info(map_info)
    if not ok then
        logger.error("Failed to update monopoly state for user %d", user_id)
        return nil
    end
    
    -- 获取地图ID (Customs值)
    local map_id = chapter_config.map_id
    
    -- 获取移动路径上所有格子的事件
    local event_ids = {}
    -- 确定移动的方向和范围
    local start_pos = from_position
    local end_pos = to_position
    local step = map_info.direction > 0 and 1 or -1
    
    -- 获取移动路径上每个格子的事件（不包括起始位置，包括最终位置）
    for pos = start_pos + step, end_pos, step do
        logger.debug("Checking events for position %d", pos)
        
        -- 获取格子数据
        local cell_data = get_cell_data(map_id, pos)
        if not cell_data then
            return nil
        end
        
        -- 获取格子事件
        local cell_event_ids = get_cell_events(cell_data, pos)
        for _, event_id in ipairs(cell_event_ids) do
            table.insert(event_ids, event_id)
        end
    end
    
    -- 如果找到了事件，将它们存储起来
    if #event_ids > 0 then
        logger.info("Found %d events on path for user %d", #event_ids, user_id)
        logger.debug("Event IDs: %s", utils.table_to_string(event_ids))
        
        -- 存储事件到数据库
        for _, event_id in ipairs(event_ids) do
            -- 创建事件记录
            local event_data = {
                user_id = user_id,
                chapter_id = map_info.chapter_id,
                cell_id = to_position,
                event_id = event_id,
                status = 0, -- 未处理
                trigger_time = os.time(),
                complete_time = 0
            }
            
            -- 调用DAO存储事件
            local ok, err = map_dao.create_monopoly_event(event_data)
            if not ok then
                logger.error("Failed to create event record for event_id=%d, chapter_id=%d, cell_id=%d: %s", 
                    event_id, map_info.chapter_id, to_position, tostring(err))
            else
                logger.debug("Created event record for event_id=%d, chapter_id=%d, cell_id=%d", 
                    event_id, map_info.chapter_id, to_position)
            end
        end
    else
        logger.debug("No events found on path from position %d to %d", from_position, to_position)
    end
    
    -- 记录操作日志
    map_dao.log_monopoly_operation({
        user_id = user_id,
        chapter_id = map_info.chapter_id,
        operation_type = OPERATION_TYPE.ROLL_DICE,
        dice_value = dice_value,
        from_position = from_position,
        to_position = to_position,
        operation_time = os.time()
    })
    
    return {
        dice_value = dice_value,
        from_position = from_position,
        to_position = to_position,
        event_ids = event_ids
    }
end

-- 处理格子事件
function M.handle_cell_event(user_id, event_id)
    if not user_id or not event_id then
        logger.error("Invalid parameters: user_id=%s, event_id=%s", 
            tostring(user_id), tostring(event_id))
        return nil
    end
    
    -- 获取用户大富翁状态
    local map_info = M.get_map_info(user_id)
    if not map_info then
        logger.error("Failed to get monopoly state for user %d", user_id)
        return nil
    end
    
    -- 获取当前格子的所有事件
    local events = map_dao.get_cell_events({
        chapter_id = map_info.chapter_id,
        cell_id = map_info.current_position
    })
    
    if not events or #events == 0 then
        logger.warn("No events found for chapter %d, position %d", 
            map_info.chapter_id, map_info.current_position)
        return {
            success = false,
            event_id = event_id,
            next_event_id = 0,
            remaining_events = {}
        }
    end
    
    -- 查找目标事件
    local target_event = nil
    local remaining_events = {}
    
    for _, event in ipairs(events) do
        if event.event_id == event_id then
            target_event = event
        else
            table.insert(remaining_events, event.event_id)
        end
    end
    
    if not target_event then
        logger.error("Event %s not found for user %d at position %d", 
            event_id, user_id, map_info.current_position)
        return {
            success = false,
            event_id = event_id,
            next_event_id = 0,
            remaining_events = remaining_events
        }
    end
    
    -- 更新事件状态为处理中
    map_dao.update_event_status(target_event.id, 1)
    
    -- 处理事件
    local success, bags, new_position = dispatch_event(user_id, target_event, map_info)
    
    -- 更新事件状态为已处理
    map_dao.update_event_status(target_event.id, 2)
    
    -- 记录操作日志
    map_dao.log_monopoly_operation({
        user_id = user_id,
        chapter_id = map_info.chapter_id,
        operation_type = OPERATION_TYPE.HANDLE_EVENT,
        event_id = event_id,
        operation_time = os.time()
    })
    
    -- 确定下一个要处理的事件
    local next_event_id = 0
    if #remaining_events > 0 then
        next_event_id = remaining_events[1]
        table.remove(remaining_events, 1)
    end
    
    return {
        success = success,
        event_id = event_id,
        bags = bags,
        new_position = new_position,
        next_event_id = next_event_id,
        remaining_events = remaining_events
    }
end

-- 领取章节奖励
function M.claim_reward(user_id)
    if not user_id then
        logger.error("Invalid user_id")
        return nil
    end
    
    -- 获取用户大富翁状态
    local map_info = M.get_map_info(user_id)
    if not map_info then
        logger.error("Failed to get monopoly state for user %d", user_id)
        return nil
    end
    
    -- 获取章节配置
    local chapter_config = M.get_chapter_config(map_info.chapter_id)
    if not chapter_config then
        logger.error("Failed to get chapter config for chapter %d", map_info.chapter_id)
        return nil
    end
    
    -- 获取章节进度
    local progress = map_dao.get_chapter_progress(user_id, map_info.chapter_id)
    
    -- 检查是否已通关
    local is_passed = false
    
    if progress then
        is_passed = (progress.is_passed == 1)
        
        -- 检查是否已领取奖励
        if progress.reward_claimed == 1 then
            logger.warn("Chapter %d reward already claimed by user %d", map_info.chapter_id, user_id)
            return {
                success = false,
                reason = "reward_already_claimed"
            }
        end
    else
        -- 检查是否达到终点
        if map_info.current_position >= chapter_config.total_cells then
            is_passed = true
            
            -- 创建章节进度记录
            local ok = map_dao.create_chapter_progress({
                user_id = user_id,
                chapter_id = map_info.chapter_id,
                is_passed = 1,
                pass_time = os.time(),
                reward_claimed = 0,
                reward_time = 0
            })
            
            if not ok then
                logger.error("Failed to create chapter progress for user %d, chapter %d", 
                    user_id, map_info.chapter_id)
                return nil
            end
            
            progress = {
                user_id = user_id,
                chapter_id = map_info.chapter_id,
                is_passed = 1,
                pass_time = os.time(),
                reward_claimed = 0,
                reward_time = 0
            }
        else
            logger.warn("Chapter %d not completed by user %d, position=%d, total=%d", 
                map_info.chapter_id, user_id, map_info.current_position, chapter_config.total_cells)
            return {
                success = false,
                reason = "chapter_not_completed"
            }
        end
    end
    
    -- 发放奖励
    local bags = {}
    
    if chapter_config.reward then
        -- 物品奖励
        if chapter_config.reward.items then
            for _, item in ipairs(chapter_config.reward.items) do
                local ok, result = bag_service.add_item(user_id, item.item_id, item.count)
                if ok and result then
                    for _, change in ipairs(result) do
                        table.insert(bags, change)
                    end
                else
                    logger.error("Failed to add item for user %d, item=%d, count=%d", 
                        user_id, item.item_id, item.count)
                end
            end
        end
        
        -- 货币奖励
        if chapter_config.reward.currency then
            for _, currency in ipairs(chapter_config.reward.currency) do
                local ok, result = bag_service.add_currency(user_id, currency.type, currency.amount)
                if ok and result then
                    for _, change in ipairs(result) do
                        table.insert(bags, change)
                    end
                else
                    logger.error("Failed to add currency for user %d, type=%d, amount=%d", 
                        user_id, currency.type, currency.amount)
                end
            end
        end
    end
    
    -- 更新章节进度，标记奖励已领取
    local ok = map_dao.update_chapter_progress({
        user_id = user_id,
        chapter_id = map_info.chapter_id,
        is_passed = 1,
        pass_time = progress.pass_time,
        reward_claimed = 1,
        reward_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to update chapter progress for user %d, chapter %d", 
            user_id, map_info.chapter_id)
        return nil
    end
    
    -- 如果当前章节已完成，进入下一章节
    local next_chapter_id = map_info.chapter_id + 1
    
    -- 检查下一章节是否存在
    local next_chapter_config = M.get_chapter_config(next_chapter_id)
    if next_chapter_config then
        -- 更新到下一章节
        map_info.chapter_id = next_chapter_id
        map_info.current_position = 0  -- 初始位置
        map_info.direction = 1  -- 初始方向（正向）
        map_info.update_time = os.time()
        
        local ok = map_dao.update_map_info(map_info)
        if not ok then
            logger.error("Failed to update map info for user %d", user_id)
            return nil
        end
    end
    
    -- 记录操作日志
    map_dao.log_monopoly_operation({
        user_id = user_id,
        chapter_id = map_info.chapter_id,
        operation_type = OPERATION_TYPE.CLAIM_REWARD,
        reward_items = bags,
        operation_time = os.time()
    })
    
    return {
        success = true,
        bags = bags,
        next_chapter = map_info.chapter_id
    }
end

return M 