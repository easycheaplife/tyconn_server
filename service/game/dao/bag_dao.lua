local skynet = require "skynet"
local logger = require "logger"
local cache = require "game.cache"
local db_client = require "game.db_client"
local item_model = require "models.item_model"
local bag_model = require "models.bag_model"
local snowflake = require "utils.snowflake"
local utils = require "utils"
local enum = require "game.define.enum"

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
            state = enum.SlotState.SLOT_STATE_EMPTY,
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

-- 更新背包大小
function M.update_bag_size(user_id, bag_type, new_size)
    -- 1. 更新数据库
    local ok = db_client.update_bag_size(user_id, bag_type, new_size)
    if not ok then
        return false
    end
    
    -- 2. 更新缓存中的背包大小
    local bag = cache.get_user_bag(user_id, bag_type)
    if bag then
        bag.size = new_size
        cache.set_user_bag(user_id, bag_type, bag)
    end
    
    -- 3. 初始化新增格子
    local slots = cache.get_bag_slots(user_id, bag_type) or {}
    local now = os.time()
    
    -- 添加新格子
    for i = (#slots + 1), new_size do
        table.insert(slots, bag_model.new_slot({
            user_id = user_id,
            bag_type = bag_type,
            slot_index = i-1,
            state = enum.SlotState.SLOT_STATE_EMPTY,
            create_time = now,
            update_time = now
        }))
    end
    
    -- 4. 保存新格子到数据库
    ok = db_client.batch_create_slots(slots)
    if not ok then
        -- 回滚背包大小
        db_client.update_bag_size(user_id, bag_type, #slots)
        return false
    end
    
    -- 5. 更新格子缓存
    cache.set_bag_slots(user_id, bag_type, slots)
    
    return true
end

-- 获取用户所有背包
function M.get_user_all_bags(user_id)
    if not user_id then
        return nil
    end

    -- 1. 从缓存获取所有背包信息
    local bags = cache.get_user_bags(user_id)
    if bags then
        -- 获取每个背包的格子信息
        for _, bag in ipairs(bags) do
            local slots = cache.get_bag_slots(user_id, bag.bag_type)
            if slots then
                bag.slots = slots
            end
        end
        return bags
    end

    -- 2. 从数据库获取所有背包
    bags = db_client.get_user_bags(user_id)
    if not bags then
        -- 3. 如果没有背包记录,创建默认背包
        -- 创建主背包(默认20格)
        local main_bag = M.create_bag(user_id, enum.BagType.BAG_TYPE_MAIN, 20)
        if not main_bag then
            return nil
        end
        
        -- 创建仓库背包(默认30格)
        local storage_bag = M.create_bag(user_id, enum.BagType.BAG_TYPE_STORAGE, 30)
        if not storage_bag then
            return nil
        end

        -- 创建装备背包(默认12格)
        local equip_bag = M.create_bag(user_id, enum.BagType.BAG_TYPE_EQUIP, 12)
        if not equip_bag then
            return nil
        end

        -- 重新获取所有背包
        bags = db_client.get_user_bags(user_id)
        if not bags then
            logger.error("Failed to get bags after creation for user: %d", user_id)
            return nil
        end
    end

    -- 4. 获取每个背包的格子信息
    for _, bag in ipairs(bags) do
        local slots = db_client.get_bag_slots(user_id, bag.bag_type)
        if slots then
            bag.slots = slots
        else
            bag.slots = {}
        end
    end

    -- 5. 写入缓存
    cache.set_user_bags(user_id, bags)
    for _, bag in ipairs(bags) do
        if bag.slots then
            cache.set_bag_slots(user_id, bag.bag_type, bag.slots)
        end
    end

    return bags
end

-- 清除缓存
function M.clear_cache(user_id)
    -- 先打印日志看看 cache 对象的内容
    logger.debug("Cache object: %s", utils.table_to_string(cache))
    
    if not cache.remove_user_items then
        logger.error("cache.remove_user_items is nil")
        return false
    end
    
    if not cache.clear_bag_cache then
        logger.error("cache.clear_bag_cache is nil")
        return false
    end

    cache.remove_user_items(user_id)
    cache.clear_bag_cache(user_id)
    return true
end

return M 