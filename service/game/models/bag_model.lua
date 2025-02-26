local snowflake = require "utils.snowflake"

local M = {}

-- 背包类型
M.BAG_TYPE = {
    MAIN = 1,      -- 主背包
    STORAGE = 2,   -- 仓库
    EQUIP = 3,     -- 装备栏
}

-- 格子状态
M.SLOT_STATE = {
    EMPTY = 0,     -- 空格子
    NORMAL = 1,    -- 正常
    LOCKED = 2,    -- 锁定
}

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
        state = params.state or M.SLOT_STATE.EMPTY,
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 验证背包数据
function M.validate_bag(bag)
    if not bag then
        return false, "背包数据为空"
    end
    
    if not bag.user_id then
        return false, "用户ID为空"
    end
    
    if not bag.bag_type then
        return false, "背包类型为空"
    end
    
    if not bag.size or bag.size <= 0 then
        return false, "背包大小无效"
    end
    
    return true
end

-- 验证格子数据
function M.validate_slot(slot)
    if not slot then
        return false, "格子数据为空"
    end
    
    if not slot.user_id then
        return false, "用户ID为空"
    end
    
    if not slot.bag_type then
        return false, "背包类型为空"
    end
    
    if not slot.slot_index or slot.slot_index < 0 then
        return false, "格子索引无效"
    end
    
    if not slot.state then
        return false, "格子状态为空"
    end
    
    return true
end

-- 验证背包类型是否有效
function M.is_valid_bag_type(bag_type)
    return bag_type == M.BAG_TYPE.MAIN or 
           bag_type == M.BAG_TYPE.STORAGE or 
           bag_type == M.BAG_TYPE.EQUIP
end

return M 