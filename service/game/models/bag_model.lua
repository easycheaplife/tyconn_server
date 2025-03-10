local snowflake = require "utils.snowflake"
local enum = require "enum"

local M = {}

-- 创建背包模型
function M.new_bag(params)
    local now = os.time()
    return {
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.BAG),  -- 使用 snowflake 生成背包 ID
        user_id = params.user_id,
        bag_type = params.bag_type,
        size = params.size,
        slots = params.slots or {},
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 创建格子模型
function M.new_slot(params)
    local now = os.time()
    return {
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.SLOT),  -- 使用 snowflake 生成格子 ID
        user_id = params.user_id,
        bag_type = params.bag_type,
        slot_index = params.slot_index,
        state = params.state or enum.SlotState.SLOT_STATE_EMPTY,
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 验证背包数据
function M.validate_bag(bag)
    if not bag then
        return false, "bag data is empty"
    end
    
    if not bag.user_id then
        return false, "user id is empty"
    end
    
    if not bag.bag_type then
        return false, "bag type is empty"
    end
    
    if not bag.size or bag.size <= 0 then
        return false, "invalid bag size"
    end
    
    return true
end

-- 验证格子数据
function M.validate_slot(slot)
    if not slot then
        return false, "slot data is empty"
    end
    
    if not slot.user_id then
        return false, "user id is empty"
    end
    
    if not slot.bag_type then
        return false, "bag type is empty"
    end
    
    if not slot.slot_index or slot.slot_index < 0 then
        return false, "invalid slot index"
    end
    
    if not slot.state then
        return false, "slot state is empty"
    end
    
    return true
end

-- 验证背包类型是否有效
function M.is_valid_bag_type(bag_type)
    return bag_type == enum.BagType.BAG_TYPE_MAIN or 
           bag_type == enum.BagType.BAG_TYPE_STORAGE or 
           bag_type == enum.BagType.BAG_TYPE_EQUIP
end

return M 