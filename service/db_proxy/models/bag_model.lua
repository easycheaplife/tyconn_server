local db_util = require "db_proxy.utils.db_util"
local sql = require "db_proxy.sql.bag_sql"
local logger = require "logger"
local snowflake = require "utils.snowflake"

local M = {}

function M.get_user_bag(user_id, bag_type)
    -- 1. 获取背包基本信息
    local query = string.format(sql.GET_USER_BAG, user_id, bag_type)
    local bag = db_util.query(query)
    if not bag or #bag == 0 then
        return nil
    end
    
    -- 2. 获取格子信息
    query = string.format(sql.GET_BAG_SLOTS, user_id, bag_type)
    local slots = db_util.query(query)
    if slots then
        bag[1].slots = slots
    end
    
    return bag[1]
end

-- 创建用户背包
function M.create_user_bag(params)
    -- 1. 创建背包
    local query = string.format(sql.CREATE_USER_BAG,
        params.id,  -- 使用传入的 snowflake ID
        params.user_id,
        params.bag_type,
        params.size,
        params.create_time,
        params.create_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        return false
    end
    
    -- 2. 创建格子
    for i = 0, params.size - 1 do
        query = string.format(sql.CREATE_BAG_SLOT,
            params.slot_ids and params.slot_ids[i+1] or snowflake.next_id(snowflake.ID_TYPE.SLOT),  -- 使用传入的 ID 或生成新 ID
            params.user_id,
            params.bag_type,
            i,  -- slot_index 从0开始
            0,  -- 初始状态为空
            params.create_time,
            params.create_time
        )
        
        ok = db_util.query(query)
        if not ok then
            -- 回滚背包创建
            db_util.query(string.format(
                "DELETE FROM user_bags WHERE user_id = %d AND bag_type = %d",
                params.user_id, params.bag_type
            ))
            return false
        end
    end
    
    return true
end

-- 批量创建格子
function M.batch_create_slots(slots)
    -- 检查参数
    if not slots or #slots == 0 then
        return false
    end

    -- 批量插入格子
    for _, slot in ipairs(slots) do
        local query = string.format(sql.CREATE_BAG_SLOT,
            slot.id,
            slot.user_id,
            slot.bag_type,
            slot.slot_index,
            slot.state,
            slot.create_time,
            slot.update_time
        )
        
        local ok = db_util.query(query)
        if not ok then
            return false
        end
    end
    
    return true
end

-- 删除用户背包
function M.delete_user_bag(user_id, bag_type)
    -- 1. 删除格子
    local query = string.format(sql.DELETE_BAG_SLOTS, user_id, bag_type)
    local ok = db_util.query(query)
    if not ok then
        return false
    end
    
    -- 2. 删除背包
    query = string.format(sql.DELETE_USER_BAG, user_id, bag_type)
    ok = db_util.query(query)
    if not ok then
        return false
    end
    
    return true
end

-- 更新格子状态
function M.update_slot_state(params)
    if not params or not params.user_id or not params.bag_type or not params.slot_index then
        return false
    end

    local query = string.format(sql.UPDATE_SLOT_STATE,
        params.state,
        params.update_time,
        params.user_id,
        params.bag_type,
        params.slot_index
    )
    
    return db_util.query(query)
end

-- 更新背包大小
function M.update_bag_size(params)
    -- 检查参数
    if not params or not params.user_id or not params.bag_type or not params.size then
        return false
    end

    local query = string.format(sql.UPDATE_BAG_SIZE,
        params.size,
        params.update_time,
        params.user_id,
        params.bag_type
    )
    
    return db_util.query(query)
end

-- 获取背包格子
function M.get_bag_slots(user_id, bag_type)
    local query = string.format(sql.GET_BAG_SLOTS, user_id, bag_type)
    local slots = db_util.query(query)
    return slots
end

-- 获取用户所有背包
function M.get_user_bags(user_id)
    if not user_id then
        return nil
    end

    -- 1. 获取所有背包基本信息
    local query = string.format(sql.GET_USER_BAGS, user_id)
    local bags = db_util.query(query)
    if not bags then
        return nil
    end

    -- 2. 获取每个背包的格子信息
    for _, bag in ipairs(bags) do
        query = string.format(sql.GET_BAG_SLOTS, user_id, bag.bag_type)
        local slots = db_util.query(query)
        if slots then
            bag.slots = slots
        else
            bag.slots = {}
        end
    end

    return bags
end

return M 