local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local map_dao = require "game.dao.map_dao"
local bag_service = require "game.services.bag_service"
local enum = require "enum"
local cjson = require "cjson"

local M = {}

-- 处理物品奖励事件
function M.handle_item_reward(user_id, complete_event)
    local bags = {}
    local success = true
    
    -- 从合并后的事件数据中获取物品信息
    if complete_event.merged_events and #complete_event.merged_events > 0 then
        -- 查找匹配的事件数据
        local event_data = nil
        for _, merged_event in ipairs(complete_event.merged_events) do
            if merged_event.event_id == complete_event.event_id then
                event_data = merged_event
                break
            end
        end
        -- 处理事件数据
        if event_data then
            local item_id, count
            if event_data.params and #event_data.params >= 2 then
                -- 如果是表格式的参数
                item_id = event_data.params[1]
                count = event_data.params[2]
            end
            
            if item_id then
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
                logger.error("Invalid item reward event data format: missing item_id")
            end
        else
            success = false
            logger.error("Event not found in merged events")
        end
    else
        success = false
        logger.error("No merged events found")
    end
    
    return success, bags, nil
end

-- 处理物品装备奖励事件
function M.handle_item_equip_reward(user_id, complete_event)
    local equip_service = require "services.equip_service"
    
    -- 1. 随机生成装备
    local equip_info = equip_service.random_equipment_by_user(user_id)
    if not equip_info then
        logger.error("Failed to generate random equipment for user %d", user_id)
        return false, nil, nil
    end
    
    -- 2. 添加装备到背包
    local ok, bags = bag_service.add_items(user_id, {
        item_id = equip_info.equip_id,
        count = 1
    }, enum.ChangeSource.SOURCE_REWARD)
    
    if not ok or not bags then
        logger.error("Failed to add equipment to bag for user %d", user_id)
        return false, nil, nil
    end
    
    -- 3. 保存装备属性
    local props_data = {
        equip_id = equip_info.equip_id,
        part = equip_info.slot_type,
        quality = equip_info.quality,
        level = equip_info.level,
        additional_props = cjson.encode(equip_info.props or {})
    }
    logger.info("handle_item_equip_reward props_data: %s", utils.table_to_string(props_data))
    ok = equip_service.save_equip_properties(props_data)
    if not ok then
        logger.error("Failed to save equipment properties for user %d, equip %d", user_id, bags.item_id)
        -- 注意：即使保存属性失败，我们也不回滚背包操作，因为装备已经生成
        -- 属性可以后续补偿或重新生成
    end
    
    -- 返回值格式：success, bags, new_position
    -- 与 handle_item_reward 保持一致
    return true, bags, nil
end

-- 处理传送事件
function M.handle_teleport(user_id, complete_event, map_info)
    local success = true
    local new_position = nil
    
    -- 从合并后的事件数据中获取目标位置
    if complete_event.merged_events and #complete_event.merged_events > 0 then
        -- 查找匹配的事件数据
        local event_data = nil
        for _, merged_event in ipairs(complete_event.merged_events) do
            if merged_event.event_id == complete_event.event_id then
                event_data = merged_event
                break
            end
        end
        
        if event_data and event_data.params and #event_data.params >= 1 then
            new_position = event_data.params[1]
            
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
            logger.error("Invalid teleport event data format or event not found")
        end
    else
        success = false
        logger.error("No merged events found")
    end
    
    return success, nil, new_position
end

-- 处理转向事件
function M.handle_direction_change(user_id, complete_event, map_info)
    local success = true
    
    -- 从合并后的事件数据中获取方向
    if complete_event.merged_events and #complete_event.merged_events > 0 then
        -- 查找匹配的事件数据
        local event_data = nil
        for _, merged_event in ipairs(complete_event.merged_events) do
            if merged_event.event_id == complete_event.event_id then
                event_data = merged_event
                break
            end
        end
        
        if event_data and event_data.params and #event_data.params >= 1 then
            local direction = event_data.params[1]
            
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
            logger.error("Invalid direction change event data format or event not found")
        end
    else
        success = false
        logger.error("No merged events found")
    end
    
    return success, nil, nil
end

-- 处理一般性事件（不需要特殊处理的事件）
function M.handle_generic_event(user_id, complete_event)
    logger.info("Handling generic event: user_id=%d, event_id=%d, merged_events=%s", 
        user_id, complete_event.event_id, utils.table_to_string(complete_event.merged_events))
    return true, nil, nil
end

return M 