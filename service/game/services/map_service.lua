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
local config_service = require "game.services.config_service"

local M = {}

-- 设置骰子点数
function M.gm_set_dice_num(num)
    logger.info("Setting dice num to: %s", tostring(num))
    
    -- 保存到Redis
    local ok = map_dao.set_gm_dice_num(num)
    if not ok then
        logger.error("Failed to save GM dice num to Redis")
    end
    
    return ok
end

-- 获取骰子点数
function M.get_gm_dice_num()
    -- 直接从Redis获取
    local dice_num = map_dao.get_gm_dice_num()
    logger.debug("Got GM dice num from Redis: %s", tostring(dice_num))
    return dice_num
end

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
local function merge_cell_events(cell_events, direction)
    local merged_events = {}
    local cell_events_configs = table_service.get_config_values("cell_events")
    if not cell_events_configs then
        logger.error("Failed to get cell_events config")
        return merged_events
    end
    
    -- 处理事件数组
    if cell_events and #cell_events > 0 then
        for _, events in ipairs(cell_events) do
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
                    source = "cell_events"
                })
            end
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
    
    -- 处理事件数组
    if cell_data.cell_events and #cell_data.cell_events > 0 then
        for _, events in ipairs(cell_data.cell_events) do
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
                if activate_type == enum.CellEventActivateType.ACTIVATE_TYPE_LAND then  -- 踩中
                    should_trigger = is_final_position == true
                elseif activate_type == enum.CellEventActivateType.ACTIVATE_TYPE_PASS then  -- 路过
                    should_trigger = true
                end
                
                if should_trigger then
                    table.insert(event_ids, {
                        event_id = event_id,
                        cell_id = position,
                        is_random_event = false  -- 非随机事件
                    })
                end
                
                ::continue::
            end
        end
    end
    
    return event_ids
end

-- 事件处理分发函数
local function dispatch_event(user_id, event, map_info)
    local success = false
    local bags = nil
    local new_position = nil
        
    logger.debug("Dispatching event: user_id=%d, event_id=%d, is_random=%s", 
        user_id, event.event_id, tostring(event.is_random_event))
    
    -- 获取格子数据
    local cell_data = get_cell_data_by_chapter(event.chapter_id, event.cell_id)
    if not cell_data then
        logger.error("Failed to get cell data for chapter %d, cell %d", 
            event.chapter_id, event.cell_id)
        return false, nil, nil
    end
    
    local event_type_id
    local complete_event
    
    -- 判断是否是随机事件
    if event.is_random_event then
        -- 获取随机事件配置
        local cell_random_events = table_service.get_config_values("cell_random_events")
        if not cell_random_events then
            logger.error("Failed to get cell_random_events config")
            return false, nil, nil
        end
        
        -- 查找特定的随机事件配置
        local random_event_config = cell_random_events[event.event_id]
        if not random_event_config then
            logger.error("Random event config not found for event_id %d", event.event_id)
            return false, nil, nil
        end
        
        -- 从随机事件配置中获取Cell_events信息
        logger.debug(utils.table_to_string(random_event_config))
        local cell_events = random_event_config.cell_events
        if not cell_events or #cell_events == 0 then
            logger.error("No Cell_events in random event config: %d", event.event_id)
            return false, nil, nil
        end
        
        -- 获取随机事件的实际事件ID
        local actual_event_id = cell_events[1]
        logger.debug("Random event %d has actual event_id: %d", event.event_id, actual_event_id)
        
        -- 获取事件类型ID
        event_type_id = M.get_event_type_id(actual_event_id)
        if not event_type_id then
            logger.error("Failed to get event type id for actual_event_id %d", actual_event_id)
            return false, nil, nil
        end
        
        -- 构造完整事件对象
        complete_event = {
            event_id = actual_event_id,
            event_type_id = event_type_id,
            cell_events = cell_events,
            merged_events = {
                {
                    event_id = actual_event_id,
                    params = {table.unpack(cell_events, 2)},
                    source = "random_event"
                }
            }
        }
    else
        -- 常规事件处理
        event_type_id = M.get_event_type_id(event.event_id)
        if not event_type_id then
            logger.error("Failed to get event type id for event_id %d", event.event_id)
            return false, nil, nil
        end
        
        complete_event = {
            event_id = event.event_id,
            event_type_id = event_type_id,
            cell_events = cell_data.cell_events,
            merged_events = merge_cell_events(cell_data.cell_events, map_info.direction)
        }
    end
    
    logger.debug("user_id: %d, event_id: %d, event_type_id: %d", user_id, event.event_id, event_type_id)
    
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
        initial = chapter_config.initial or {},
        next_chapter = chapter_config.unlock or 0,
        tile_map = chapter_config.tile_map or {}
    }
end

-- 根据权重选择随机配置
local function select_random_config(configs)
    if not configs or #configs == 0 then
        return nil
    end
    
    -- 计算总权重
    local total_weight = 0
    for _, config in ipairs(configs) do
        total_weight = total_weight + (config.weights or 100)
    end
    
    -- 随机选择
    local random_weight = math.random(1, total_weight)
    local current_weight = 0
    
    for _, config in ipairs(configs) do
        current_weight = current_weight + (config.weights or 100)
        if random_weight <= current_weight then
            return config
        end
    end
    
    -- 默认返回第一个配置
    return configs[1]
end

-- 检查格子是否有事件
local function has_events(cell_config)
    return cell_config.cell_events and #cell_config.cell_events > 0
end

-- 获取已经有事件的格子
local function get_occupied_cells(map_id)
    local occupied_cells = {}
    
    -- 从配置文件获取已有事件的格子
    local cell_data_config = table_service.get_config_values("cell_data")
    if cell_data_config and cell_data_config[map_id] then
        for cell_id, cell_config in pairs(cell_data_config[map_id]) do
            if has_events(cell_config) then
                occupied_cells[cell_id] = true
            end
        end
    end
    
    return occupied_cells
end

-- 选择随机格子
local function select_random_cell(available_cells, user_id, chapter_id, mutex)
    if not available_cells or #available_cells == 0 then
        return nil
    end
    
    -- 获取章节配置以获取地图ID
    local chapter_config = M.get_chapter_config(chapter_id)
    if not chapter_config then
        logger.error("Failed to get chapter config for chapter %d", chapter_id)
        return nil
    end
    
    -- 获取地图ID
    local map_id = chapter_config.map_id
    if not map_id then
        logger.error("No map_id found for chapter %d", chapter_id)
        return nil
    end
    
    -- 获取已经有事件的格子
    local occupied_cells = {}
    
    -- 1. 从配置文件获取已有事件的格子
    local cell_data_config = table_service.get_config_values("cell_data")
    if cell_data_config and cell_data_config[map_id] then
        for cell_id, cell_config in pairs(cell_data_config[map_id]) do
            if has_events(cell_config) then
                occupied_cells[cell_id] = true
            end
        end
    end
    
    -- 2. 从数据库/缓存获取已有事件的格子
    local db_occupied_cells = map_dao.get_occupied_cells(user_id, chapter_id)
    for cell_id, _ in pairs(db_occupied_cells) do
        occupied_cells[cell_id] = true
    end
    
    -- 根据互斥值筛选格子
    local valid_cells = {}
    
    if mutex == enum.MutexType.MUTEX_TYPE_EXCLUSIVE then
        -- 互斥：只选择没有事件的格子
        for _, cell_id in ipairs(available_cells) do
            if not occupied_cells[cell_id] then
                table.insert(valid_cells, cell_id)
            end
        end
    else -- mutex == enum.MutexType.MUTEX_TYPE_NO_LIMIT or mutex == enum.MutexType.MUTEX_TYPE_REPLACE
        -- 无限制：可以放在任何可用格子上;
        -- 替换: 先不限制，在处理事件时处理;
        valid_cells = available_cells
    end
    
    if #valid_cells == 0 then
        logger.warn("No valid cells available for random event, mutex=%d", mutex)
        return nil
    end
    
    -- 随机选择一个格子
    local random_index = math.random(1, #valid_cells)
    return valid_cells[random_index]
end

-- 辅助函数，处理随机事件生成的共同逻辑
local function process_random_event_generation(user_id, chapter_config, selected_config)
    -- 检查最大生成数量限制
    if selected_config.max_gen > 0 then
        local existing_count = map_dao.count_random_events(user_id, chapter_config.id, selected_config.id)
        if existing_count >= selected_config.max_gen then
            logger.debug("Random event %d reached max generation limit", selected_config.id)
            return false, nil
        end
    end
    
    -- 选择放置格子
    local cell_id = select_random_cell(selected_config.cells, user_id, chapter_config.id, selected_config.mutex)
    if not cell_id then
        logger.error("Failed to select random cell for event %d", selected_config.id)
        return false, nil
    end
    
    -- 创建随机事件记录
    local event_data = {
        user_id = user_id,
        chapter_id = chapter_config.id,
        event_id = selected_config.id,
        cell_id = cell_id,
        create_time = os.time(),
        update_time = os.time()
    }
    
    local ok = map_dao.create_random_event(event_data)
    if not ok then
        logger.error("Failed to create random event record")
        return false, nil
    else
        logger.info("Created random event: event_id=%d, cell_id=%d", 
            selected_config.id, cell_id)
            
        -- 创建事件对象返回
        local event_info = {
            event_id = selected_config.id,
            cell_id = cell_id,
            chapter_id = chapter_config.id,
            is_random_event = true
        }
        
        return true, event_info
    end
end

-- 生成随机事件
local function generate_random_events(user_id, chapter_config)
    if not chapter_config.initial or #chapter_config.initial == 0 then
        logger.debug("No initial events to generate for chapter %d", chapter_config.id)
        return {}
    end
    
    logger.info("Generating random events for user %d, chapter %d", 
        user_id, chapter_config.id)
    
    -- 获取随机事件配置
    local cell_random_events = table_service.get_config_values("cell_random_events")
    if not cell_random_events then
        logger.error("Failed to get cell_random_events config")
        return {}
    end
   
    -- 用于保存生成的随机事件
    local generated_events = {}
   
    -- 遍历初始化配置
    for _, initial_config in ipairs(chapter_config.initial) do
        -- 检查是否是随机事件配置 (第一个元素是900)
        if M.get_event_type_id(initial_config[1]) == enum.CellEventType.EVENT_TYPE_RANDOM_EVENT then
            local map_id = initial_config[2]  -- 随机组ID
            local count = initial_config[3] or 1  -- 生成数量
            
            -- 查找对应的随机配置
            local random_config_group = {}
            for _, config in pairs(cell_random_events) do
                if config.map_id == map_id then
                    table.insert(random_config_group, config)
                end
            end
            
            if #random_config_group == 0 then
                logger.warn("No random event config found for map_id %d", map_id)
                goto continue
            end
            
            -- 生成随机事件
            for i = 1, count do
                -- 根据权重选择配置
                local selected_config = select_random_config(random_config_group)
                if not selected_config then
                    logger.error("Failed to select random config for map_id %d", map_id)
                    goto continue
                end
                
                -- 使用辅助函数处理随机事件生成
                local success, event_info = process_random_event_generation(user_id, chapter_config, selected_config)
                if success and event_info then
                    table.insert(generated_events, event_info)
                end
            end
            
            ::continue::
        end
    end
    
    return generated_events
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
            event_info.is_random_event = false  -- 标记为非随机事件
            table.insert(event_ids, event_info)
        end
    end
    
    return event_ids
end

-- 获取随机事件的真实事件ID
local function get_random_event_real_id(random_event_id)
    if not random_event_id then
        logger.error("Invalid random_event_id")
        return nil
    end
    
    -- 获取随机事件配置
    local cell_random_events = table_service.get_config_values("cell_random_events")
    if not cell_random_events then
        logger.error("Failed to get cell_random_events config")
        return nil
    end
    
    -- 查找特定的随机事件配置
    local random_event_config = cell_random_events[random_event_id]
    if not random_event_config then
        logger.error("Random event config not found for random_event_id %d", random_event_id)
        return nil
    end
    
    -- 从随机事件配置中获取Cell_events信息的第一个元素（真实事件ID）
    if not random_event_config.cell_events or #random_event_config.cell_events == 0 then
        logger.error("No Cell_events in random event config: %d", random_event_id)
        return nil
    end
    
    -- 返回Cell_events的第一个元素作为真实事件ID
    local real_event_id = random_event_config.cell_events[1]
    logger.debug("Random event %d has real event_id: %d", random_event_id, real_event_id)
    return real_event_id
end

-- 检查事件触发次数限制
local function check_event_trigger_limit(user_id, chapter_id, all_events)
    -- 获取事件配置
    local cell_events_config = table_service.get_config_values("cell_events")
    if not cell_events_config then
        logger.error("Failed to get cell_events config")
        return all_events
    end
    
    local filtered_events = {}
    
    for _, event in ipairs(all_events) do
        local event_id = nil
        local event_to_check = event.event_id
        
        -- 处理随机事件，获取真实事件ID
        if event.is_random_event then
            local real_id = get_random_event_real_id(event.event_id)
            if real_id then
                event_to_check = real_id
                logger.debug("Using real event ID %d for random event %d", real_id, event.event_id)
            else
                logger.error("Failed to get real event ID for random event %d", event.event_id)
            end
        end
        
        -- 查找事件表ID
        for id, config in pairs(cell_events_config) do
            if config.event_id == event_to_check then
                event_id = id
                break
            end
        end
        
        if event_id then
            local config = cell_events_config[event_id]
            
            -- 检查是否有触发次数限制
            if config.one_off > 0 then
                -- 获取当前触发次数
                local trigger_data = map_dao.get_event_trigger_count(user_id, chapter_id, event_id)
                local trigger_count = 0
                
                if trigger_data then
                    trigger_count = trigger_data.trigger_count
                end
                
                logger.debug("Event %d (table_id %d) trigger count: %d, limit: %d", 
                    event_to_check, event_id, trigger_count, config.one_off)
                
                -- 判断是否已达到触发次数限制
                if trigger_count >= config.one_off then
                    logger.info("Event %d has reached its trigger limit %d for user %d, skipping", 
                        event_to_check, config.one_off, user_id)
                    -- 不添加到过滤后的事件列表
                else
                    -- 未达到限制，添加到过滤后的事件列表
                    table.insert(filtered_events, event)
                end
            else
                -- 无限制事件，直接添加
                table.insert(filtered_events, event)
            end
        else
            -- 未找到配置的事件，按无限制处理
            table.insert(filtered_events, event)
        end
    end
    
    return filtered_events
end

-- 增加事件触发次数
local function increment_event_trigger_counts(user_id, chapter_id, events)
    logger.debug("Incrementing event trigger counts for user %d, chapter %d, events: %s", user_id, chapter_id, utils.table_to_string(events))
    -- 获取事件配置
    local cell_events_config = table_service.get_config_values("cell_events")
    if not cell_events_config then
        logger.error("Failed to get cell_events config")
        return
    end
    logger.debug("Cell events config: %s", utils.table_to_string(cell_events_config))
    
    for _, event in ipairs(events) do
        local event_id = nil
        local event_to_check = event.event_id
        
        -- 处理随机事件，获取真实事件ID
        if event.is_random_event then
            local real_id = get_random_event_real_id(event.event_id)
            if real_id then
                event_to_check = real_id
                logger.debug("Using real event ID %d for random event %d", real_id, event.event_id)
            else
                logger.error("Failed to get real event ID for random event %d", event.event_id)
            end
        end
        
        -- 查找事件表ID
        for id, config in pairs(cell_events_config) do
            if config.event_id == event_to_check then
                event_id = id
                break
            end
        end
        
        if event_id then
            local config = cell_events_config[event_id]
            
            -- 只有有限制的事件才需要增加触发次数
            logger.debug("Event config: %s", utils.table_to_string(config))
            if config.one_off > 0 then
                local ok, new_count = map_dao.increment_event_trigger_count(user_id, chapter_id, event_id)
                if ok then
                    logger.debug("Incremented trigger count for event_id %d to %d", event_id, new_count)
                else
                    logger.error("Failed to increment trigger count for event_id %d", event_id)
                end
            end
        end
    end
end

-- 保存事件到数据库
local function save_path_events(user_id, chapter_id, event_ids)
    local saved_events = {}
    
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
                is_random_event = event_info.is_random_event and 1 or 0, -- 转换布尔值为数字
                trigger_time = os.time(),
                complete_time = 0
            }
            
            -- 调用DAO存储事件
            local ok, err = map_dao.create_monopoly_event(event_data)
            if not ok then
                logger.error("Failed to create event record for event_id=%d, chapter_id=%d, cell_id=%d: %s", 
                    event_info.event_id, chapter_id, event_info.cell_id, tostring(err))
            else
                logger.debug("Created event record for event_id=%d, chapter_id=%d, cell_id=%d, is_random=%d", 
                    event_info.event_id, chapter_id, event_info.cell_id, event_data.is_random_event)
                -- 将成功保存的事件添加到返回列表
                table.insert(saved_events, event_info)
            end
        end
    end
    
    return saved_events
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
        
        -- 获取章节配置
        local chapter_config = M.get_chapter_config(new_map.chapter_id)
        if chapter_config then
            -- 生成随机事件并获取生成的事件
            local initial_events = generate_random_events(user_id, chapter_config)
            logger.info("Generated %d initial random events for user %d", #initial_events, user_id)
        else
            logger.error("Failed to get chapter config for chapter %d", new_map.chapter_id)
        end
        
        map_info = new_map
    end
    
    return map_info
end

-- 生成路径上的随机事件
local function generate_path_random_events(user_id, chapter_config, path_cells)
    if not user_id or not chapter_config or not path_cells or #path_cells == 0 then
        logger.debug("No path cells to generate random events for user %d", user_id)
        return {}
    end
    
    logger.info("Generating path random events for user %d, chapter %d", 
        user_id, chapter_config.id)
    
    -- 获取随机事件配置
    local cell_random_events = table_service.get_config_values("cell_random_events")
    if not cell_random_events then
        logger.error("Failed to get cell_random_events config")
        return {}
    end
    
    -- 用于保存生成的随机事件
    local generated_events = {}
    
    -- 遍历路径上的每个格子
    for _, cell_id in ipairs(path_cells) do
        -- 获取格子数据
        local cell_data = M.get_cell_data(chapter_config.map_id, cell_id)
        if not cell_data then
            logger.warn("No cell data found for cell %d", cell_id)
            goto continue
        end
        
        -- 处理事件数组
        if cell_data.cell_events and #cell_data.cell_events > 0 then
            for _, events in ipairs(cell_data.cell_events) do
                if events and #events > 0 and type(events[1]) == "number" then
                    local event_id = events[1]
                    local event_type_id = M.get_event_type_id(event_id)
                    
                    -- 检查是否是随机事件配置
                    if event_type_id == enum.CellEventType.EVENT_TYPE_RANDOM_EVENT then
                        local map_id = events[2]  -- 随机组ID
                        local count = events[3] or 1  -- 生成数量
                        
                        -- 查找对应的随机配置
                        local random_config_group = {}
                        for _, config in pairs(cell_random_events) do
                            if config.map_id == map_id then
                                table.insert(random_config_group, config)
                            end
                        end
                        
                        if #random_config_group == 0 then
                            logger.warn("No random event config found for map_id %d", map_id)
                            goto continue
                        end
                        
                        -- 生成随机事件
                        for i = 1, count do
                            -- 根据权重选择配置
                            local selected_config = select_random_config(random_config_group)
                            if not selected_config then
                                logger.error("Failed to select random config for map_id %d", map_id)
                                goto continue
                            end
                            
                            -- 使用辅助函数处理随机事件生成
                            local success, event_info = process_random_event_generation(user_id, chapter_config, selected_config)
                            if success and event_info then
                                table.insert(generated_events, event_info)
                            end
                        end
                    end
                end
            end
        end
        
        ::continue::
    end
    
    return generated_events
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
    
    local dice_result = math.random(1, 6)
    
    -- 如果骰子点数被GM指定，则使用GM指定的骰子点数
    local gm_dice = M.get_gm_dice_num()
    if gm_dice ~= nil then
        logger.info("User %d rolled with GM specified dice: %d", user_id, gm_dice)
        dice_result = gm_dice
    else
        logger.info("User %d rolled random dice: %d", user_id, dice_result)
    end

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
    local to_position = calculate_new_position(from_position, dice_result, map_info.direction, chapter_config)
    
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
    local path_event_ids = get_path_events(chapter_config.map_id, from_position, to_position, map_info.direction, map_info.chapter_id)
    if not path_event_ids then
        return nil
    end
    
    -- 获取路径上的所有格子ID列表
    local path_cells = {}
    local step = map_info.direction > 0 and 1 or -1
    for pos = from_position + step, to_position, step do
        table.insert(path_cells, pos)
    end
    
    -- 生成格子上的随机事件，并获取生成的随机事件列表
    local new_random_events = generate_path_random_events(user_id, chapter_config, path_cells)
    
    -- 获取路径上已存在的随机事件
    local existing_random_events = map_dao.get_random_events_by_cells(user_id, map_info.chapter_id, path_cells)
    logger.info("Found %d existing random events on path for user %d", #existing_random_events, user_id)
    
    -- 合并路径事件和已存在的随机事件
    local all_events = path_event_ids
    for _, event in ipairs(existing_random_events) do
        table.insert(all_events, {
            event_id = event.event_id,
            cell_id = event.cell_id,
            chapter_id = map_info.chapter_id,
            is_random_event = true  -- 标记为随机事件
        })
    end
    
    -- 过滤掉事件类型为EVENT_TYPE_RANDOM_EVENT的事件
    -- 从后向前遍历，避免删除元素时的索引问题
    for i = #all_events, 1, -1 do
        local event = all_events[i]
        if M.get_event_type_id(event.event_id) == enum.CellEventType.EVENT_TYPE_RANDOM_EVENT then
            table.remove(all_events, i)
        end
    end
    
    logger.debug("All events before filtering: %s", utils.table_to_string(all_events))
    -- 过滤掉达到触发次数限制的事件
    all_events = check_event_trigger_limit(user_id, map_info.chapter_id, all_events)
    logger.debug("All events after filtering: %s", utils.table_to_string(all_events))
    
    -- 保存事件到数据库
    local saved_events = save_path_events(user_id, map_info.chapter_id, all_events)
    
    -- 增加事件触发次数
    increment_event_trigger_counts(user_id, map_info.chapter_id, saved_events)
    
    -- 记录操作日志
    map_dao.log_monopoly_operation({
        user_id = user_id,
        chapter_id = map_info.chapter_id,
        operation_type = enum.MonopolyOperationType.MONOPOLY_OPERATION_TYPE_ROLL_DICE,
        dice_value = dice_result,
        from_position = from_position,
        to_position = to_position,
        operation_time = os.time()
    })
    
    -- 合并新生成的随机事件和路径上已有的随机事件，为响应提供完整的随机事件信息
    local all_random_events = {}
    
    -- 添加新生成的随机事件
    for _, event in ipairs(new_random_events) do
        table.insert(all_random_events, {
            event_id = event.event_id,
            cell_id = event.cell_id,
            is_random_event = true
        })
    end
    
    return {
        dice_value = dice_result,
        from_position = from_position,
        to_position = to_position,
        event_ids = all_events,
        random_events = all_random_events  -- 添加随机事件到响应中
    }
end

-- 获取目标事件和剩余事件
local function get_target_event(events, event_id, cell_id)
    local target_event = nil
    local remaining_events = {}
    
    if not events or #events == 0 then
        logger.warn("get_target_event: events is empty")
        return nil, {}
    end
    
    if not event_id then
        logger.warn("get_target_event: event_id is nil")
        return nil, {}
    end
    
    -- 确保事件ID是数字
    event_id = tonumber(event_id) or event_id
    
    for _, event in ipairs(events) do
        if type(event) ~= "table" then
            logger.warn("get_target_event: invalid event type: %s", type(event))
            goto continue
        end
        
        if not event.event_id then
            logger.warn("get_target_event: event missing event_id")
            goto continue
        end
        
        local event_event_id = tonumber(event.event_id) or event.event_id
        
        if event_event_id == event_id and event.cell_id == cell_id then
            target_event = event
        else
            table.insert(remaining_events, event.event_id)
        end
        
        ::continue::
    end
    
    return target_event, remaining_events
end

-- 处理事件状态更新
local function update_event_status(event_id, status)
    if not event_id or not status then
        logger.error("update_event_status: Invalid parameters: event_id=%s, status=%s", 
            tostring(event_id), tostring(status))
        return false
    end
    
    local ok = map_dao.update_event_status(event_id, status)
    if not ok then
        logger.error("update_event_status: Failed to update status for event_id=%s to status=%d",
            tostring(event_id), status)
        return false
    end
    
    return true
end

-- 记录事件处理操作
local function log_event_operation(user_id, chapter_id, event_id, cell_id)
    map_dao.log_monopoly_operation({
        user_id = user_id,
        chapter_id = chapter_id,
        operation_type = enum.MonopolyOperationType.MONOPOLY_OPERATION_TYPE_HANDLE_EVENT,
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
        cell_id = cell_id,
        status = 0
    })
    
    if not events or #events == 0 then
        logger.warn("No events found for chapter %d, cell_id %d", 
            map_info.chapter_id, cell_id)
        return {
            success = false,
            event_info = {
                event_id = event_id,
                cell_id = cell_id,
                is_random_event = false
            },
            next_event = {
                event_id = 0,
                cell_id = 0,
                is_random_event = false
            },
            remaining_events = {}
        }
    end
    
    -- 安全检查事件数据格式
    local valid_events = {}
    for _, event in ipairs(events) do
        if type(event) == "table" and event.event_id and event.cell_id then
            -- 将数字类型的is_random_event转换为布尔值
            if event.is_random_event ~= nil then
                event.is_random_event = event.is_random_event == 1
            end
            table.insert(valid_events, event)
        else
            logger.warn("Invalid event data format: %s", utils.table_to_string(event))
        end
    end
    
    if #valid_events == 0 then
        logger.warn("No valid events found for chapter %d, cell_id %d", 
            map_info.chapter_id, cell_id)
        return {
            success = false,
            event_info = {
                event_id = event_id,
                cell_id = cell_id,
                is_random_event = false
            },
            next_event = {
                event_id = 0,
                cell_id = 0,
                is_random_event = false
            },
            remaining_events = {}
        }
    end
    
    -- 获取目标事件和剩余事件
    local target_event, remaining_event_ids = get_target_event(valid_events, event_id, cell_id)
    
    if not target_event then
        logger.error("Event %s not found for user %d at cell_id %d", 
            event_id, user_id, cell_id)
        return {
            success = false,
            event_info = {
                event_id = event_id,
                cell_id = cell_id,
                is_random_event = false
            },
            next_event = {
                event_id = 0,
                cell_id = 0,
                is_random_event = false
            },
            remaining_events = {}
        }
    end
    
    -- 更新事件状态为处理中
    local status_updated = update_event_status(target_event.id, 1)
    if not status_updated then
        logger.warn("Failed to update event status to processing for event %d", target_event.id)
    end
    
    -- 处理事件
    local success, bags, new_position = dispatch_event(user_id, target_event, map_info)
    
    -- 更新事件状态为已处理
    status_updated = update_event_status(target_event.id, 2)
    if not status_updated then
        logger.warn("Failed to update event status to completed for event %d", target_event.id)
    end
    map_dao.remove_cell_events_cache(map_info.chapter_id, cell_id)
    -- 记录操作日志
    log_event_operation(user_id, map_info.chapter_id, event_id, cell_id)
    
    -- 查找剩余事件的详细信息
    local next_event = {
        event_id = 0,
        cell_id = 0,
        is_random_event = false
    }
    
    local remaining_events = {}
    
    -- 构建剩余事件列表
    if remaining_event_ids and #remaining_event_ids > 0 then
        -- 查找剩余事件的完整信息
        for _, remaining_id in ipairs(remaining_event_ids) do
            -- 查找对应的事件详情
            for _, event in ipairs(valid_events) do
                if event.event_id == remaining_id then
                    table.insert(remaining_events, {
                        event_id = event.event_id,
                        cell_id = event.cell_id,
                        is_random_event = event.is_random_event or false
                    })
                    break
                end
            end
        end
        
        -- 设置下一个事件
        if #remaining_events > 0 then
            next_event = remaining_events[1]
            table.remove(remaining_events, 1)
        end
    end
    
    return {
        success = success,
        event_info = {
            event_id = event_id,
            cell_id = cell_id,
            is_random_event = target_event.is_random_event or false
        },
        bags = bags,
        new_position = new_position,
        next_event = next_event,
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
            local passed_stages = map_dao.get_user_passed_chapters(user_id)
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
        operation_type = enum.MonopolyOperationType.MONOPOLY_OPERATION_TYPE_CLAIM_REWARD,
        reward_items = bags,
        operation_time = os.time()
    })
    
    return {
        success = true,
        bags = bags,
        next_chapter = map_info.chapter_id
    }
end

-- 获取地图上的随机事件
function M.get_random_events(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("Invalid parameters: user_id=%s, chapter_id=%s", 
            tostring(user_id), tostring(chapter_id))
        return {}
    end
    
    -- 从数据库获取随机事件
    local random_events = map_dao.get_random_events(user_id, chapter_id)
    if not random_events or #random_events == 0 then
        logger.debug("No random events found for user %d, chapter %d", user_id, chapter_id)
        return {}
    end
    
    -- 转换为EventInfo格式
    local event_infos = {}
    for _, event in ipairs(random_events) do
        table.insert(event_infos, {
            event_id = event.event_id,
            cell_id = event.cell_id,
            is_random_event = true
        })
    end
    
    logger.debug("Found %d random events for user %d, chapter %d", 
        #event_infos, user_id, chapter_id)
    return event_infos
end

-- 获取事件触发次数记录
function M.get_event_triggers(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("Invalid parameters: user_id=%s, chapter_id=%s", 
            tostring(user_id), tostring(chapter_id))
        return {}
    end
    
    -- 从数据库获取事件触发记录
    local trigger_records = map_dao.get_chapter_event_triggers(user_id, chapter_id)
    if not trigger_records or #trigger_records == 0 then
        logger.debug("No event trigger records found for user %d, chapter %d", user_id, chapter_id)
        return {}
    end
    
    -- 转换为EventTrigger格式
    local event_triggers = {}
    for _, record in ipairs(trigger_records) do
        table.insert(event_triggers, {
            chapter_id = record.chapter_id,
            event_id = record.event_id,
            trigger_count = record.trigger_count
        })
    end
    
    logger.debug("Found %d event trigger records for user %d, chapter %d", 
        #event_triggers, user_id, chapter_id)
    return event_triggers
end

return M 