local skynet = require "skynet"
local logger = require "logger"
local cache = require "game.cache"
local db_client = require "game.db_client"
local item_model = require "models.item_model"
local bag_model = require "models.bag_model"
local snowflake = require "utils.snowflake"

local M = {}

-- 获取用户背包
function M.get_user_bag(user_id, bag_type)
    -- 1. 从缓存获取背包基本信息
    local bag = cache.get_user_bag(user_id, bag_type)
    local slots = cache.get_bag_slots(user_id, bag_type)
    
    if bag and slots then
        bag.slots = slots
        return bag
    end
    
    -- 2. 从数据库获取背包信息
    local db_bag = db_client.get_user_bag(user_id, bag_type)
    if not db_bag then
        return nil
    end
    
    -- 3. 从数据库获取格子信息
    local db_slots = db_client.get_bag_slots(user_id, bag_type)
    if db_slots then
        db_bag.slots = db_slots
    else
        db_bag.slots = {}
    end
    
    -- 4. 写入缓存
    cache.set_user_bag(user_id, bag_type, db_bag)
    cache.set_bag_slots(user_id, bag_type, db_bag.slots)
    
    return db_bag
end

-- 更新用户背包
function M.update_user_bag(user_id, bag_type, bag_data)
    -- 1. 更新数据库
    local ok = db_client.update_user_bag(user_id, bag_type, bag_data)
    if not ok then
        return false
    end
    
    -- 2. 更新缓存
    cache.set_user_bag(user_id, bag_type, bag_data)
    if bag_data.slots then
        cache.set_bag_slots(user_id, bag_type, bag_data.slots)
    end
    
    return true
end

-- 获取用户背包信息
function M.get_user_bags(user_id)
    -- 1. 从缓存获取
    local bags = cache.get_user_bags(user_id)
    if bags then
        return bags
    end
    
    -- 2. 从数据库获取
    bags = db_client.get_user_bags(user_id)
    if not bags then
        return nil
    end
    
    -- 3. 写入缓存
    cache.set_user_bags(user_id, bags)
    
    return bags
end

-- 获取背包格子状态
function M.get_bag_slots(user_id, bag_type)
    -- 1. 从缓存获取
    local slots = cache.get_bag_slots(user_id, bag_type)
    if slots then
        return slots
    end
    
    -- 2. 从数据库获取
    slots = db_client.get_bag_slots(user_id, bag_type)
    if not slots then
        return nil
    end
    
    -- 3. 写入缓存
    cache.set_bag_slots(user_id, bag_type, slots)
    
    return slots
end

-- 更新格子状态
function M.update_slot_state(user_id, bag_type, slot_index, state)
    -- 1. 更新数据库
    local ok = db_client.update_slot_state(user_id, bag_type, slot_index, state)
    if not ok then
        return false
    end
    
    -- 2. 更新缓存
    local slots = cache.get_bag_slots(user_id, bag_type)
    if slots then
        for _, slot in ipairs(slots) do
            if slot.slot_index == slot_index then
                slot.state = state
                slot.update_time = os.time()
                break
            end
        end
        cache.set_bag_slots(user_id, bag_type, slots)
    end
    
    return true
end

-- 创建背包
function M.create_bag(user_id, bag_type, size)
    -- 1. 创建背包
    local bag = bag_model.new_bag({
        user_id = user_id,
        bag_type = bag_type,
        size = size
    })
    
    -- 2. 保存到数据库
    local ok = db_client.create_user_bag({
        id = bag.id,  -- 使用 snowflake 生成的 ID
        user_id = user_id,
        bag_type = bag_type,
        size = size,
        create_time = os.time(),
        update_time = os.time()
    })
    
    if not ok then
        return nil
    end
    
    -- 3. 初始化格子
    local slots = {}
    local now = os.time()
    for i = 1, size do
        table.insert(slots, bag_model.new_slot({
            user_id = user_id,
            bag_type = bag_type,
            slot_index = i-1,
            state = bag_model.SLOT_STATE.EMPTY,
            create_time = now,
            update_time = now
        }))
    end
    
    ok = db_client.batch_create_slots(slots)
    if not ok then
        -- 回滚背包创建
        db_client.delete_user_bag(user_id, bag_type)
        return nil
    end
    
    -- 4. 写入缓存
    bag.slots = slots
    cache.set_user_bag(user_id, bag_type, bag)
    cache.set_bag_slots(user_id, bag_type, slots)  -- 缓存格子信息
    
    return bag
end

return M 