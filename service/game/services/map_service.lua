local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local map_dao = require "game.dao.map_dao"
local map_model = require "game.models.map_model"
local table_service = require "game.services.table_service"
local bag_service = require "game.services.bag_service"
local user_service = require "game.services.user_service"
local error = require "error"
local enum = require "enum"
local event_handlers = require "game.services.map_event_handlers"

local M = {}

-- 操作类型常量
local OPERATION_TYPE = {
    ROLL_DICE = 1,     -- 掷骰子
    HANDLE_EVENT = 2,  -- 处理事件
    CLAIM_REWARD = 3   -- 领取奖励
}

-- 获取事件类型ID
function M.get_event_type_id(event_id)
    if not event_id then
        logger.error("Invalid event_id")
        return nil
    end
    
    -- 从配置获取事件信息
    local event_configs = table_service.get_config_values("cell_events")
    if not event_configs then
        logger.error("Failed to get cell_events config")
        return nil
    end
    
    -- 获取特定事件的配置
    local event_config = event_configs[event_id]
    if not event_config then
        logger.error("Event config not found for event_id %d", event_id)
        return nil
    end
    
    return event_config.event_type_id
end

-- 获取格子数据
function M.get_cell_data(map_id, position)
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
    return M.get_cell_data(chapter_config.map_id, cell_id)
end

-- 合并格子事件
local function merge_cell_events(cell_events1, cell_events2, cell_events3, direction)
    local merged_events = {}
    local cell_events_configs = table_service.get_config_values("cell_events")
    if not cell_events_configs then
        logger.error("Failed to get cell_events config")
        return merged_events
    end
    
    -- 处理所有事件数组
    local event_arrays = {
        {events = cell_events1, source = "cell_events1"},
        {events = cell_events2, source = "cell_events2"},
        {events = cell_events3, source = "cell_events3"}
    }
    
    for _, array_info in ipairs(event_arrays) do
        local events = array_info.events
        if events and #events > 0 and type(events[1]) == "number" then
            -- 获取事件ID和参数
            local event_id = events[1]
            local params = {}
            for i = 2, #events do
                table.insert(params, events[i])
            end
            
            -- 添加事件，触发逻辑在后续根据activate判断
            table.insert(merged_events, {
                event_id = event_id,
                params = params,
                source = array_info.source
            })
        end
    end
    
    logger.debug("merged_events: %s", utils.table_to_string(merged_events))
    return merged_events
end

-- 获取格子事件
local function get_cell_events(cell_data, position, is_final_position)
    if not cell_data then
        return {}
    end

    local event_ids = {}
    local cell_events_configs = table_service.get_config_values("cell_events")
    if not cell_events_configs then
        logger.error("Failed to get cell_events config")
        return {}
    end
    
    -- 处理所有事件数组
    local event_arrays = {
        cell_data.cell_events1,
        cell_data.cell_events2,
        cell_data.cell_events3
    }
    
    for _, events in ipairs(event_arrays) do
        if events and #events > 0 and type(events[1]) == "number" then
            local event_id = events[1]
            
            -- 获取事件配置中的Activate值
            local event_config = cell_events_configs[event_id]
            if not event_config then
                logger.error("Event config not found for event_id %d", event_id)
                goto continue
            end
            
            local activate_type = event_config.activate or 0
            local should_trigger = false
            
            -- 根据activate_type判断触发条件
            if activate_type == enum.CellEventActivateType.ACTIVATE_TYPE_CALL then  -- 调用生效
                should_trigger = true
            elseif activate_type == enum.CellEventActivateType.ACTIVATE_TYPE_LAND then  -- 踩中
                should_trigger = is_final_position == true
            elseif activate_type == enum.CellEventActivateType.ACTIVATE_TYPE_PASS then  -- 路过
                should_trigger = true
            end
            
            if should_trigger then
                table.insert(event_ids, {
                    event_id = event_id,
                    cell_id = position
                })
            end
            
            ::continue::
        end
    end
    
    return event_ids
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
    
    -- 获取事件类型ID
    local event_type_id = M.get_event_type_id(event.event_id)
    if not event_type_id then
        logger.error("Failed to get event type id for event_id %d", event.event_id)
        return false, nil, nil
    end
    logger.debug("user_id: %d, event_id: %d, event_type_id: %d", user_id, event.event_id, event_type_id)
    
    -- 合并事件配置和事件数据
    local complete_event = {
        event_id = event.event_id,
        event_type_id = event_type_id,
        cell_events1 = cell_data.cell_events1,
        cell_events2 = cell_data.cell_events2,
        cell_events3 = cell_data.cell_events3,
        merged_events = merge_cell_events(cell_data.cell_events1, cell_data.cell_events2, cell_data.cell_events3, map_info.direction)
    }
    
    -- 根据事件类型调用对应的处理函数
    if event_type_id == enum.CellEventType.EVENT_TYPE_ITEM_REWARD then
        success, bags, new_position = event_handlers.handle_item_reward(user_id, complete_event)
    elseif event_type_id == enum.CellEventType.EVENT_TYPE_JUMP then
        success, bags, new_position = event_handlers.handle_teleport(user_id, complete_event, map_info)
    elseif event_type_id == enum.CellEventType.EVENT_TYPE_TURN then
        success, bags, new_position = event_handlers.handle_direction_change(user_id, complete_event, map_info)
    elseif event_type_id == enum.CellEventType.EVENT_TYPE_ITEM_EQUIP_REWARD then
        success, bags, new_position = event_handlers.handle_item_equip_reward(user_id, complete_event)
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
        victory_condition = chapter_config.victory_condition or {},
        chapter_reward = chapter_config.reward or {},
        next_chapter = chapter_config.unlock or 0,
        tile_map = chapter_config.tile_map or {}
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
            current_position = 1, -- 初始位置为1
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

-- 计算骰子移动后的位置
local function calculate_new_position(from_position, dice_value, direction, chapter_config)
    local current_position = from_position
    local steps_remaining = dice_value
    
    -- 获取地图配置
    local tile_map = chapter_config.tile_map
    if not tile_map then
        logger.error("No tile map found for chapter %d", chapter_config.id)
        return from_position
    end
    
    logger.debug("Starting movement from position %d, steps: %d, direction: %d", 
        current_position, steps_remaining, direction)
    
    -- 根据方向移动
    while steps_remaining > 0 do
        local current_tile = tile_map[current_position]
        if not current_tile then
            logger.error("Invalid tile position %d in chapter %d", current_position, chapter_config.id)
            return from_position
        end
        
        -- 获取下一个位置
        local next_positions = current_tile.next_ids
        if not next_positions or #next_positions == 0 then
            logger.error("No next positions for tile %d in chapter %d", current_position, chapter_config.id)
            return from_position
        end
        
        -- 根据方向选择下一个位置
        local next_position
        if direction > 0 then
            -- 正向移动，选择第一个下一个位置
            next_position = next_positions[1]
        else
            -- 反向移动，选择最后一个下一个位置
            next_position = next_positions[#next_positions]
        end
        
        if not next_position then
            logger.error("Invalid next position for tile %d in chapter %d", current_position, chapter_config.id)
            return from_position
        end
        
        -- 更新位置
        current_position = next_position
        steps_remaining = steps_remaining - 1
        
        logger.debug("Moved to position %d, steps remaining: %d", current_position, steps_remaining)
        
        -- 检查是否到达终点
        if current_position == chapter_config.total_cells then
            logger.debug("Reached end position %d", current_position)
            break
        end
    end
    
    logger.debug("Final position: %d", current_position)
    return current_position
end

-- 获取移动路径上的事件
local function get_path_events(map_id, from_position, to_position, direction, chapter_id)
    local event_ids = {}
    local step = direction > 0 and 1 or -1
    
    -- 获取移动路径上每个格子的事件（不包括起始位置，包括最终位置）
    for pos = from_position + step, to_position, step do
        logger.debug("Checking events for position %d", pos)
        
        -- 获取格子数据
        local cell_data = M.get_cell_data(map_id, pos)
        if not cell_data then
            return nil
        end
        
        -- 获取格子事件，传入是否是最终位置
        local cell_event_ids = get_cell_events(cell_data, pos, pos == to_position)
        for _, event_info in ipairs(cell_event_ids) do
            event_info.chapter_id = chapter_id
            table.insert(event_ids, event_info)
        end
    end
    
    return event_ids
end

-- 保存事件到数据库
local function save_path_events(user_id, chapter_id, event_ids)
    if #event_ids > 0 then
        logger.info("Found %d events on path for user %d", #event_ids, user_id)
        logger.debug("Events: %s", utils.table_to_string(event_ids))
        
        -- 存储事件到数据库
        for _, event_info in ipairs(event_ids) do
            -- 创建事件记录
            local event_data = {
                user_id = user_id,
                chapter_id = chapter_id,
                cell_id = event_info.cell_id,
                event_id = event_info.event_id,
                status = 0, -- 未处理
                trigger_time = os.time(),
                complete_time = 0
            }
            
            -- 调用DAO存储事件
            local ok, err = map_dao.create_monopoly_event(event_data)
            if not ok then
                logger.error("Failed to create event record for event_id=%d, chapter_id=%d, cell_id=%d: %s", 
                    event_info.event_id, chapter_id, event_info.cell_id, tostring(err))
            else
                logger.debug("Created event record for event_id=%d, chapter_id=%d, cell_id=%d", 
                    event_info.event_id, chapter_id, event_info.cell_id)
            end
        end
    end
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
    
    logger.debug("Chapter config: %s", utils.table_to_string(chapter_config))
    
    -- 计算新位置（使用tileMap配置）
    local to_position = calculate_new_position(from_position, dice_value, map_info.direction, chapter_config)
    
    -- 更新位置
    map_info.current_position = to_position
    map_info.update_time = os.time()
    
    -- 保存更新
    local ok = map_dao.update_map_info(map_info)
    if not ok then
        logger.error("Failed to update monopoly state for user %d", user_id)
        return nil
    end
    
    -- 获取移动路径上的事件
    local event_ids = get_path_events(chapter_config.map_id, from_position, to_position, map_info.direction, map_info.chapter_id)
    if not event_ids then
        return nil
    end
    
    -- 保存事件到数据库
    save_path_events(user_id, map_info.chapter_id, event_ids)
    
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

-- 获取目标事件和剩余事件
local function get_target_event(events, event_id, cell_id)
    local target_event = nil
    local remaining_events = {}
    
    for _, event in ipairs(events) do
        if event.event_id == event_id and event.cell_id == cell_id then
            target_event = event
        else
            table.insert(remaining_events, event.event_id)
        end
    end
    
    return target_event, remaining_events
end

-- 处理事件状态更新
local function update_event_status(event_id, status)
    map_dao.update_event_status(event_id, status)
end

-- 记录事件处理操作
local function log_event_operation(user_id, chapter_id, event_id, cell_id)
    map_dao.log_monopoly_operation({
        user_id = user_id,
        chapter_id = chapter_id,
        operation_type = OPERATION_TYPE.HANDLE_EVENT,
        event_id = event_id,
        cell_id = cell_id,
        operation_time = os.time()
    })
end

-- 处理格子事件
function M.handle_cell_event(user_id, event_id, cell_id)
    if not user_id or not event_id or not cell_id then
        logger.error("Invalid parameters: user_id=%s, event_id=%s, cell_id=%s", 
            tostring(user_id), tostring(event_id), tostring(cell_id))
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
        cell_id = cell_id
    })
    
    if not events or #events == 0 then
        logger.warn("No events found for chapter %d, cell_id %d", 
            map_info.chapter_id, cell_id)
        return {
            success = false,
            event_id = event_id,
            next_event_id = 0,
            remaining_events = {}
        }
    end
    
    -- 获取目标事件和剩余事件
    local target_event, remaining_events = get_target_event(events, event_id, cell_id)
    
    if not target_event then
        logger.error("Event %s not found for user %d at cell_id %d", 
            event_id, user_id, cell_id)
        return {
            success = false,
            event_id = event_id,
            next_event_id = 0,
            remaining_events = remaining_events
        }
    end
    
    -- 更新事件状态为处理中
    update_event_status(target_event.id, 1)
    
    -- 处理事件
    local success, bags, new_position = dispatch_event(user_id, target_event, map_info)
    
    -- 更新事件状态为已处理
    update_event_status(target_event.id, 2)
    
    -- 记录操作日志
    log_event_operation(user_id, map_info.chapter_id, event_id, cell_id)
    
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

-- 检查章节进度
local function check_chapter_progress(progress, chapter_id, user_id)
    if progress then
        local is_passed = (progress.is_passed == 1)
        
        -- 检查是否已领取奖励
        if progress.reward_claimed == 1 then
            logger.warn("Chapter %d reward already claimed by user %d", chapter_id, user_id)
            return {
                success = false,
                reason = "reward_already_claimed"
            }
        end
        
        return {
            success = true,
            is_passed = is_passed,
            progress = progress
        }
    end
    
    return {
        success = true,
        is_passed = false,
        progress = nil
    }
end

-- 检查胜利条件
local function check_victory_conditions(victory_conditions, map_info, user_id, chapter_config)
    if not victory_conditions or #victory_conditions == 0 then
        logger.error("No victory conditions defined for chapter %d", map_info.chapter_id)
        return {
            success = false,
            reason = "no_victory_conditions"
        }
    end
    
    -- 检查每个胜利条件
    for _, condition in ipairs(victory_conditions) do
        local condition_type = condition[1]
        local condition_value = condition[2]
        
        if condition_type == enum.ChapterConditionType.CONDITION_TYPE_REACH_END then
            -- 检查是否到达终点
            if map_info.current_position < chapter_config.total_cells then
                return {
                    success = false,
                    reason = "not_reached_end"
                }
            end
        elseif condition_type == enum.ChapterConditionType.CONDITION_TYPE_PLAYER_LEVEL then
            -- 检查玩家等级
            local user_level = user_service.get_user_level(user_id)
            if user_level < condition_value then
                return {
                    success = false,
                    reason = "level_not_enough"
                }
            end
        elseif condition_type == enum.ChapterConditionType.CONDITION_TYPE_PASS_STAGES then
            -- 检查通过的关卡数
            local passed_stages = map_dao.get_user_passed_stages(user_id)
            if not passed_stages or #passed_stages < condition_value then
                return {
                    success = false,
                    reason = "stages_not_enough"
                }
            end
        end
    end
    
    return {
        success = true,
        is_passed = true
    }
end

-- 创建章节进度记录
local function create_chapter_progress(user_id, chapter_id)
    local progress = {
        user_id = user_id,
        chapter_id = chapter_id,
        is_passed = 1,
        pass_time = os.time(),
        reward_claimed = 0,
        reward_time = 0
    }
    
    local ok = map_dao.create_chapter_progress(progress)
    if not ok then
        logger.error("Failed to create chapter progress for user %d, chapter %d", 
            user_id, chapter_id)
        return nil
    end
    
    return progress
end

-- 发放章节奖励
local function grant_chapter_rewards(user_id, chapter_config)
    local bags = {}
    
    if chapter_config.chapter_reward and #chapter_config.chapter_reward > 0 then
        -- 物品奖励
        for _, item in ipairs(chapter_config.chapter_reward) do
            if type(item) == "table" and #item >= 2 then
                local item_id = item[1]
                local item_count = item[2]
                local ok, result = bag_service.add_item(user_id, item_id, item_count, enum.ChangeSource.SOURCE_REWARD)
                if ok and result then
                    for _, bag_change in ipairs(result) do
                        table.insert(bags, bag_change)
                    end
                else
                    logger.error("Failed to add item for user %d, item=%d, count=%d", 
                        user_id, item_id, item_count)
                end
            end
        end
    end
    
    return bags
end

-- 更新章节进度
local function update_chapter_progress(progress, user_id, chapter_id)
    local ok = map_dao.update_chapter_progress({
        user_id = user_id,
        chapter_id = chapter_id,
        is_passed = 1,
        pass_time = progress.pass_time,
        reward_claimed = 1,
        reward_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to update chapter progress for user %d, chapter %d", 
            user_id, chapter_id)
        return false
    end
    
    return true
end

-- 进入下一章节
local function enter_next_chapter(map_info, next_chapter_id)
    -- 检查下一章节是否存在
    local next_chapter_config = M.get_chapter_config(next_chapter_id)
    if next_chapter_config then
        -- 更新到下一章节
        map_info.chapter_id = next_chapter_id
        map_info.current_position = 1  -- 初始位置
        map_info.direction = 1  -- 初始方向（正向）
        map_info.update_time = os.time()
        
        local ok = map_dao.update_map_info(map_info)
        if not ok then
            logger.error("Failed to update map info for user %d", map_info.user_id)
            return false
        end
    end
    
    return true
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
    
    logger.info("get_chapter_config %s", utils.table_to_string(chapter_config))
    
    -- 获取章节进度
    local progress = map_dao.get_chapter_progress(user_id, map_info.chapter_id)
    
    -- 检查章节进度
    local progress_check = check_chapter_progress(progress, map_info.chapter_id, user_id)
    if not progress_check.success then
        return progress_check
    end
    
    -- 如果没有进度记录，检查胜利条件
    if not progress then
        local victory_check = check_victory_conditions(chapter_config.victory_condition, map_info, user_id, chapter_config)
        if not victory_check.success then
            return victory_check
        end
        
        -- 创建章节进度记录
        progress = create_chapter_progress(user_id, map_info.chapter_id)
        if not progress then
            return nil
        end
    end
    
    -- 发放奖励
    local bags = grant_chapter_rewards(user_id, chapter_config)
    
    -- 更新章节进度
    if not update_chapter_progress(progress, user_id, map_info.chapter_id) then
        return nil
    end
    
    -- 进入下一章节
    if not enter_next_chapter(map_info, chapter_config.next_chapter) then
        return nil
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