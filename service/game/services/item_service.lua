local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local item_model = require "models.item_model"
local item_dao = require "dao.item_dao"
local snowflake = require "utils.snowflake"
local bag_dao = require "dao.bag_dao"
local property_service = require "services.property_service"
local bag_model = require "models.bag_model"
local utils = require "utils"
local config_service = require "services.config_service"
local enum = require "enum"
local init = require "game.init"  -- 添加引用
local table_service = require "services.table_service"

local M = {}
-- 初始化新用户物品
function M.init_user_items(user_id)
    if not user_id then
        return false, "invalid user id"
    end

    logger.info("Initializing items for user: %d", user_id)

    -- 1. 创建主背包
    local bag = bag_dao.get_user_bag(user_id, enum.BagType.BAG_TYPE_MAIN)
    if not bag then
        return false, "get bag failed"
    end

    -- 2. 添加默认物品
    local default_items = config_service.get_initial_items()
    if #default_items > 0 then
        -- 记录每个物品的变化
        for _, item in ipairs(default_items) do
            item_dao.log_change(user_id, item.item_id, item.count,
                enum.ChangeType.CHANGE_TYPE_ADD, enum.ChangeSource.SOURCE_INIT,
                0, item.count)  -- 从0增加到指定数量
        end

        local ok, err = M.add_items_to_slot(user_id, default_items, enum.ChangeSource.SOURCE_INIT)
        if not ok then
            logger.error("Failed to add default items for user %d: %s", user_id, err)
            return false, err
        end
    end

    return true
end

-- 应用物品效果
local function apply_item_effect(user_id, item_id, count, source)
    logger.debug("Applying item effect - user_id: %d, item_id: %d, count: %d", 
        user_id, item_id, count)
    local config = config_service.get_item_config(item_id)
    if not config then
        return false, "item config is not exist", nil
    end
    
    -- 检查物品是否有效果值
    if not config.effect_value then
        logger.error("Item %d has no effect_value defined in configuration", item_id)
        return false, "item has no effect value", nil
    end
    
    -- 创建效果物品列表
    local effect_items = {}
    
    -- 3. 应用效果
    local total_effect = config.effect_value * count    
    
    -- 根据效果类型处理
    if config.effect_type == enum.EffectType.EFFECT_TYPE_EXP then
        -- 增加经验
        local ok, err = M.add_special_item(user_id, enum.SpecialItemID.SPECIAL_ITEM_ID_EXP, total_effect, source)
        if not ok then
            logger.error("Failed to add exp: %s", err)
            return false, err, nil
        end
        -- 添加到效果物品列表
        table.insert(effect_items, {
            item_id = enum.SpecialItemID.ITEM_ID_EXP,
            count = total_effect
        })
    elseif config.effect_type == enum.EffectType.EFFECT_TYPE_GOLD then
        -- 增加金币
        local ok, err = M.add_special_item(user_id, enum.SpecialItemID.SPECIAL_ITEM_ID_GOLD, total_effect, source)
        if not ok then
            logger.error("Failed to add gold: %s", err)
            return false, err, nil
        end
        -- 添加到效果物品列表
        table.insert(effect_items, {
            item_id = enum.SpecialItemID.SPECIAL_ITEM_ID_GOLD,
            count = total_effect
        })
    end
    
    -- 触发物品使用事件
    local event = init.get_service("event")
    skynet.send(event, "lua", "trigger_event", "on_item_used", {
        user_id = user_id,
        item_id = item_id,
        count = count,
        effect_result = {
            total_effect = total_effect,
            effect_type = config.effect_type,
            effect_items = effect_items
        }
    })
    
    return true, nil, effect_items
end

-- 添加物品到指定格子
function M.add_items_to_slot(user_id, items, source, bag_type)
    -- 设置默认值
    bag_type = bag_type or enum.BagType.BAG_TYPE_MAIN

    -- 支持单个物品对象或物品对象数组
    local items_array = {}
    if items.item_id then
        -- 单个物品对象
        table.insert(items_array, {
            item_id = items.item_id,
            count = items.count or 1
        })
    else
        -- 物品对象数组
        items_array = items
    end
    
    logger.info("add_items_to_slot - user_id: %d, items: %s, source: %d", 
        user_id, utils.table_to_string(items_array), source)
    
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        logger.error("Failed to get bag for user %d, bag_type %d", user_id, bag_type)
        return false, "get bag failed"
    end
    
    -- 2. 获取物品列表
    local existing_items = item_dao.get_user_items(user_id) or {}
    
    -- 3. 找到已使用的槽位和已存在的物品
    local used_slots = {}
    local slot_item_map = {} -- 用于存储slot_index对应的物品
    for _, item in ipairs(existing_items) do
        if item.bag_type == bag_type then
            used_slots[item.slot_index] = true
            slot_item_map[item.slot_index] = item
        end
    end
    
    -- 处理每个物品
    local all_successful = true
    local error_message = nil
    
    for _, item_data in ipairs(items_array) do
        local item_id = item_data.item_id
        local count = item_data.count or 1
        local slot_index = item_data.slot_index -- 如果指定了格子
        
        logger.info("Processing item_id: %d, count: %d", item_id, count)
        
        -- 4. 获取物品配置
        local config = config_service.get_item_config(item_id)
        if not config then
            logger.error("Item config not found for item_id: %d", item_id)
            all_successful = false
            error_message = "item config not found"
            break
        end
        
        -- 5. 处理堆叠逻辑
        local remaining_count = count
        
        -- 如果物品可无限堆叠 (max_stack = 0)
        if config.max_stack == 0 then
            -- 尝试找已有的同类物品并堆叠
            for _, item in ipairs(existing_items) do
                if item.item_id == item_id and item.bag_type == bag_type then
                    item.count = item.count + remaining_count
                    remaining_count = 0
                    break
                end
            end
            
            -- 如果没有找到已有物品，创建新物品
            if remaining_count > 0 then
                -- 找一个空槽位
                local empty_slot = nil
                if slot_index and not used_slots[slot_index] then
                    -- 如果指定了槽位并且该槽位为空
                    empty_slot = slot_index
                    used_slots[slot_index] = true
                else
                    -- 没有指定槽位，自动查找空槽位
                    for i = 0, bag.size - 1 do
                        if not used_slots[i] then
                            empty_slot = i
                            used_slots[i] = true  -- 标记为已使用
                            break
                        end
                    end
                end
                
                if not empty_slot then
                    logger.error("No empty slot found for infinite stack item")
                    all_successful = false
                    error_message = "bag is full"
                    break
                end
                
                -- 检查指定槽位是否已有物品(但可能是不同ID的同类物品)
                local existing_item = slot_item_map[empty_slot]
                local item_id_to_use = nil
                
                if existing_item and existing_item.item_id == item_id then
                    -- 如果槽位已存在相同类型的物品，使用现有ID
                    item_id_to_use = existing_item.id
                    -- 从现有物品列表中移除，后面会用新的替换
                    for i, item in ipairs(existing_items) do
                        if item.id == item_id_to_use then
                            table.remove(existing_items, i)
                            break
                        end
                    end
                else
                    -- 如果是新格子或不同物品，生成新ID
                    item_id_to_use = snowflake.next_id(snowflake.ID_TYPE.ITEM)
                end
                
                -- 创建新物品
                local new_item = item_model.new({
                    id = item_id_to_use,
                    user_id = user_id,
                    item_id = item_id,
                    count = remaining_count,
                    bag_type = bag_type,
                    slot_index = empty_slot
                })
                
                table.insert(existing_items, new_item)
                remaining_count = 0
            end
        else
            -- 物品有堆叠上限或不可堆叠
            local max_per_slot = config.max_stack > 0 and config.max_stack or 1
            
            -- 尝试堆叠到已有物品
            for _, item in ipairs(existing_items) do
                if item.item_id == item_id and item.bag_type == bag_type and item.count < max_per_slot then
                    local can_add = math.min(remaining_count, max_per_slot - item.count)
                    item.count = item.count + can_add
                    remaining_count = remaining_count - can_add
                    
                    if remaining_count <= 0 then
                        break
                    end
                end
            end
            
            -- 如果还有剩余物品，创建新物品堆
            while remaining_count > 0 do
                -- 找一个空槽位
                local empty_slot = nil
                if slot_index and not used_slots[slot_index] then
                    -- 如果指定了槽位并且该槽位为空
                    empty_slot = slot_index
                    used_slots[slot_index] = true
                else
                    -- 没有指定槽位，自动查找空槽位
                    for i = 0, bag.size - 1 do
                        if not used_slots[i] then
                            empty_slot = i
                            used_slots[i] = true  -- 标记为已使用
                            break
                        end
                    end
                end
                
                if not empty_slot then
                    logger.error("No empty slot found for remaining items")
                    all_successful = false
                    error_message = "bag is full"
                    break
                end
                
                -- 每个格子放最大数量
                local slot_count = math.min(remaining_count, max_per_slot)
                
                -- 检查指定槽位是否已有物品(但可能是不同ID的同类物品)
                local existing_item = slot_item_map[empty_slot]
                local item_id_to_use = nil
                
                if existing_item and existing_item.item_id == item_id then
                    -- 如果槽位已存在相同类型的物品，使用现有ID
                    item_id_to_use = existing_item.id
                    -- 从现有物品列表中移除，后面会用新的替换
                    for i, item in ipairs(existing_items) do
                        if item.id == item_id_to_use then
                            table.remove(existing_items, i)
                            break
                        end
                    end
                else
                    -- 如果是新格子或不同物品，生成新ID
                    item_id_to_use = snowflake.next_id(snowflake.ID_TYPE.ITEM)
                end
                
                -- 创建新物品
                local new_item = item_model.new({
                    id = item_id_to_use,
                    user_id = user_id,
                    item_id = item_id,
                    count = slot_count,
                    bag_type = bag_type,
                    slot_index = empty_slot
                })
                
                table.insert(existing_items, new_item)
                remaining_count = remaining_count - slot_count
            end
        end
        
        -- 如果因为背包满导致还有剩余物品，则添加失败
        if remaining_count > 0 then
            all_successful = false
            error_message = "bag is full"
            break
        end
    end
    
    -- 6. 保存更新
    if all_successful then
        local ok = item_dao.update_user_items(user_id, existing_items)
        if not ok then
            logger.error("Failed to save updated items")
            return false, "save failed"
        end
        
        logger.info("Successfully added all items")
        return true, "success"
    else
        logger.error("Failed to add some items: %s", error_message)
        return false, error_message
    end
end

-- 检查物品是否被锁定
local function check_item_locked(item)
    if not item then
        return true
    end
    
    -- 添加日志输出
    logger.debug("Checking item lock state - user_id: %d, item_id: %d, count: %d, state: %d",
        item.user_id, item.item_id, item.count, item.state)
        
    return item.state == enum.ItemState.ITEM_STATE_LOCKED or
           item.state == enum.ItemState.ITEM_STATE_TRADING or
           item.state == enum.ItemState.ITEM_STATE_AUCTIONING
end

-- 使用物品
function M.use_item(user_id, item_id, count)
    -- 1. 检查参数
    if not user_id or not item_id or not count or count <= 0 then
        return false, 'invalid params', {}            
    end
    
    -- 2. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, 'get item failed', {}
    end
    
    -- 3. 查找物品
    local target_item = nil
    local target_index = nil
    for i, item in ipairs(items) do
        if item.item_id == item_id then
            target_item = item
            target_index = i
            break
        end
    end
    
    if not target_item then
        return false, 'item not found', {}
    end
    
    -- 4. 检查物品是否被锁定
    if check_item_locked(target_item) then
        -- 添加详细的错误日志
        logger.error("Item is locked - user_id: %d, item_id: %d, count: %d, state: %s",
            user_id, item_id, count, target_item.state or "nil")
        return false, 'item locked', {}
    end
    
    -- 检查物品数量是否足够
    if target_item.count < count then
        logger.error("item not enough - user_id: %d, item_id: %d, count: %d, have: %d", 
            user_id, item_id, count, target_item.count)
        return false, 'item not enough', {}
    end
    
    -- 记录变更前数量
    local before_count = target_item.count
    
    -- 更新数量
    target_item.count = target_item.count - count
    target_item.update_time = os.time()
    
    -- 记录物品变化
    item_dao.log_change(user_id, item_id, count,
        enum.ChangeType.CHANGE_TYPE_USE, enum.ChangeSource.SOURCE_USE,
        before_count, target_item.count)

    -- 备份target_item 并返回
    local result_item = target_item

    -- 如果物品数量为0，从列表中删除并清空格子
    if target_item.count <= 0 then
        -- 保存格子信息
        local bag_type = target_item.bag_type
        local slot_index = target_item.slot_index
        
        -- 从列表中删除
        table.remove(items, target_index)
        
        -- 更新格子状态为空
        if bag_type and slot_index then
            bag_dao.update_slot_state(user_id, bag_type, slot_index, enum.SlotState.SLOT_STATE_EMPTY)
        end
    end

    -- 更新数据库和缓存
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, 'db error', {}
    end

    -- 应用物品效果
    local ok, err, effect_items = apply_item_effect(user_id, item_id, count, enum.ChangeSource.SOURCE_USE)
    if not ok then
        logger.error("Failed to apply item effect - user_id: %d, item_id: %d, error: %s",
            user_id, item_id, err)
        return false, 'item effect failed', {}
    end

    -- 记录操作日志
    logger.info("Used item - user_id: %d, item_id: %d, count: %d, remain: %d",
        user_id, item_id, count, target_item.count)

    -- 返回变化的物品列表和效果物品
    return true, 'success', {result_item, effect_items = effect_items or {}}
end

-- 获取用户物品列表
function M.get_user_items(user_id)
    if not user_id then
        return nil, "invalid user id"
    end

    -- 从 dao 层获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        -- 新用户，返回空列表
        return {}
    end
    return items
end

-- 检查物品数据是否有效
local function validate_item(item)
    -- 1. 基础检查
    local ok, err = item_model.validate(item)
    if not ok then
        return false, err
    end
    
    -- 2. 检查物品配置
    local config = config_service.get_item_config(item.item_id)
    if not config then
        return false, "item config is not exist"
    end
    
    -- 3. 检查堆叠数量
    if config.max_stack and item.count > config.max_stack then
        return false, "exceed max stack count"
    end
    
    return true
end

-- 修复物品数据
function M.repair_user_items(user_id)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return true
    end
    
    -- 2. 检查并修复每个物品
    local valid_items = {}
    for _, item in ipairs(items) do
        local ok, err = validate_item(item)
        if ok then
            table.insert(valid_items, item)
        else
            logger.error("Invalid item found for user %d: %s", 
                user_id, utils.table_to_string(item))
        end
    end
    
    -- 3. 保存修复后的数据
    if #valid_items < #items then
        local ok = item_dao.update_user_items(user_id, valid_items)
        if not ok then
            return false, "save item data failed"
        end
    end
    
    return true
end

-- 获取物品合成配置
local function get_compose_config(item_id)
    local config = require("config.compose_config")[item_id]
    if not config then
        return nil
    end
    return config
end

-- 检查合成材料是否足够
local function check_compose_materials(items, materials)
    local material_count = {}
    -- 统计现有材料
    for _, item in ipairs(items) do
        material_count[item.item_id] = (material_count[item.item_id] or 0) + item.count
    end
    
    -- 检查是否满足需求
    for item_id, need_count in pairs(materials) do
        if (material_count[item_id] or 0) < need_count then
            return false
        end
    end
    
    return true
end

-- 检查物品是否过期
local function check_item_expired(item)
    -- 检查过期时间
    if item.expire_time and os.time() >= item.expire_time then
        return true
    end
    
    -- 检查使用限制
    if item.use_limit_type == enum.UseLimitType.TOTAL and 
        item.used_count >= item.use_limit_count then
        return true
    end
    
    return false
end

-- 批量移除物品
function M.batch_remove_items(user_id, item_list)
    -- 1. 参数检查
    if not user_id or not item_list or #item_list == 0 then
        return false, "params error"
    end
    
    -- 2. 获取当前物品
    local current_items = M.get_user_items(user_id)
    if not current_items then
        return false, "get item failed"
    end
    
    -- 3. 检查数量是否足够
    local need_count = {}
    for _, item_info in ipairs(item_list) do
        need_count[item_info.item_id] = (need_count[item_info.item_id] or 0) + item_info.count
    end
    
    local have_count = {}
    for _, item in ipairs(current_items) do
        have_count[item.item_id] = (have_count[item.item_id] or 0) + item.count
    end
    
    for item_id, count in pairs(need_count) do
        if (have_count[item_id] or 0) < count then
            return false, string.format("item %d count is not enough", item_id)
        end
    end
    
    -- 4. 批量移除
    for item_id, need_count in pairs(need_count) do
        local remain_count = need_count
        for i = #current_items, 1, -1 do
            if current_items[i].item_id == item_id then
                local remove_count = math.min(remain_count, current_items[i].count)
                current_items[i].count = current_items[i].count - remove_count
                remain_count = remain_count - remove_count
                
                -- 记录变化
                item_dao.log_change(user_id, item_id, remove_count,
                    enum.ChangeType.CHANGE_TYPE_REDUCE, enum.ChangeSource.SOURCE_BATCH_REMOVE,
                    current_items[i].count + remove_count, current_items[i].count)
                
                -- 如果数量为0则移除
                if current_items[i].count <= 0 then
                    table.remove(current_items, i)
                end
                
                if remain_count <= 0 then
                    break
                end
            end
        end
    end
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, current_items)
    if not ok then
        return false, "save item failed"
    end
    
    return true
end

-- 交易物品
function M.trade_items(from_user, to_user, item_list)
    -- 1. 参数检查
    if not from_user or not to_user or not item_list or #item_list == 0 then
        return false, "params error"
    end
    
    -- 2. 检查是否可交易
    for _, item_info in ipairs(item_list) do
        -- 检查是否被锁定
        local items = M.get_user_items(from_user)
        for _, item in ipairs(items) do
            if item.item_id == item_info.item_id then
                local locked, err = check_item_locked(item)
                if locked then
                    return false, err
                end
                break
            end
        end
        
        -- 获取物品配置
        local config = config_service.get_item_config(item_info.item_id)
        if not config then
            return false, string.format("item %d config is not exist", item_info.item_id)
        end
        
        -- 检查是否可交易
        if config.no_trade then
            return false, string.format("item %d is not tradeable", item_info.item_id)
        end
    end
    
    -- 3. 从源用户移除物品
    local ok, err = M.batch_remove_items(from_user, item_list)
    if not ok then
        return false, err
    end
    
    -- 4. 添加物品到目标用户
    ok, err = M.add_items_to_slot(to_user, item_list, enum.ChangeSource.SOURCE_TRADE)
    if not ok then
        -- 交易失败，回滚源用户物品
        M.add_items_to_slot(from_user, item_list)
        return false, err
    end
    
    -- 5. 记录交易日志
    for _, item_info in ipairs(item_list) do
        item_dao.log_trade(from_user, to_user, item_info.item_id, item_info.count)
    end
    
    return true
end

-- 锁定物品
function M.lock_item(user_id, item_id, lock_type, reason)
    -- 1. 参数检查
    if not user_id or not item_id then
        return false, "params error"
    end
    
    -- 2. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 3. 查找并锁定物品
    local found = false
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            -- 检查是否已锁定
            local locked, err = check_item_locked(item)
            if locked then
                return false, err
            end
            
            -- 锁定物品
            item.lock_type = lock_type or item_model.LOCK_TYPE.USER
            item.lock_time = os.time()
            item.lock_reason = reason
            item.update_time = os.time()
            
            -- 记录变化
            item_dao.log_change(user_id, item_id, item.count,
                enum.ChangeType.CHANGE_TYPE_LOCK, enum.ChangeSource.SOURCE_LOCK,
                item.count, item.count)
            
            found = true
            break
        end
    end
    
    if not found then
        return false, "item is not exist"
    end
    
    -- 4. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    return true
end

-- 解锁物品
function M.unlock_item(user_id, item_id)
    -- 1. 参数检查
    if not user_id or not item_id then
        return false, "params error"
    end
    
    -- 2. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 3. 查找并解锁物品
    local found = false
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            -- 检查是否已锁定
            local locked = check_item_locked(item)
            if not locked then
                return false, "item is not locked"
            end
            
            -- 解锁物品
            item.lock_type = item_model.LOCK_TYPE.NONE
            item.lock_time = nil
            item.lock_reason = nil
            item.update_time = os.time()
            
            -- 记录变化
            item_dao.log_change(user_id, item_id, item.count,
                enum.ChangeType.CHANGE_TYPE_UNLOCK, enum.ChangeSource.SOURCE_UNLOCK,
                item.count, item.count)
            
            found = true
            break
        end
    end
    
    if not found then
        return false, "item is not exist"
    end
    
    -- 4. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    return true
end

-- 获取物品最大堆叠数
local function get_max_stack(item_id)
    local config = config_service.get_item_config(item_id)   
    if not config then
        return 1
    end
    return config.max_stack or 1
end

-- 堆叠物品
function M.stack_items(user_id, bag_type, from_slot, to_slot)
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)  -- 直接使用 dao 层
    if not bag then
        return false, "get bag failed"
    end
    
    -- 2. 检查格子
    if not bag.slots[from_slot] or not bag.slots[to_slot] then
        return false, "slot is not exist"
    end
    
    -- 3. 检查源格子和目标格子
    local src_slot = bag.slots[from_slot]
    local dst_slot = bag.slots[to_slot]
    
    if src_slot.state ~= enum.SlotState.SLOT_STATE_OCCUPIED then
        return false, "src slot is not occupied"
    end
    
    if dst_slot.state ~= enum.SlotState.SLOT_STATE_OCCUPIED then
        return false, "dst slot is not occupied"
    end
    
    -- 4. 检查是否为同类物品
    if src_slot.item_id ~= dst_slot.item_id then
        return false, "different type of items cannot be stacked"
    end
    
    -- 5. 检查是否可堆叠
    local max_stack = get_max_stack(src_slot.item_id)
    if max_stack <= 1 then
        return false, "item cannot be stacked"
    end
    
    -- 6. 计算可堆叠数量
    local can_stack = max_stack - dst_slot.count
    if can_stack <= 0 then
        return false, "dst slot has reached the max stack"
    end
    
    -- 7. 执行堆叠
    local stack_count = math.min(can_stack, src_slot.count)
    
    -- 记录变更前数量
    local src_before = src_slot.count
    local dst_before = dst_slot.count
    
    -- 更新数量
    dst_slot.count = dst_slot.count + stack_count
    src_slot.count = src_slot.count - stack_count
    
    -- 记录物品变化
    item_dao.log_change(user_id, src_slot.item_id, stack_count,
        enum.ChangeType.CHANGE_TYPE_REDUCE, enum.ChangeSource.SOURCE_STACK,
        src_before, src_slot.count)
    
    item_dao.log_change(user_id, dst_slot.item_id, stack_count,
        enum.ChangeType.CHANGE_TYPE_ADD, enum.ChangeSource.SOURCE_STACK,
        dst_before, dst_slot.count)
    
    -- 如果源格子数量为0，清空格子
    if src_slot.count <= 0 then
        bag.slots[from_slot] = {
            index = from_slot,
            state = enum.SlotState.SLOT_STATE_EMPTY
        }
    end
    
    -- 8. 保存更新
    local ok = bag_dao.update_user_bag(user_id, bag_type, bag)
    if not ok then
        return false, "save bag failed"
    end
    
    return true
end

-- 快速堆叠
function M.quick_stack(user_id, bag_type)
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)  -- 直接使用 dao 层
    if not bag then
        return false, "get bag failed"
    end
    
    -- 2. 遍历所有格子尝试堆叠
    local need_update = false
    for i = 1, bag.size do
        local src_slot = bag.slots[i]
        if src_slot.state == enum.SlotState.SLOT_STATE_OCCUPIED then
            -- 查找可堆叠的目标格子
            for j = 1, i-1 do
                local dst_slot = bag.slots[j]
                if dst_slot.state == enum.SlotState.SLOT_STATE_OCCUPIED and
                    dst_slot.item_id == src_slot.item_id then
                    -- 尝试堆叠
                    local ok = M.stack_items(user_id, bag_type, i, j)
                    if ok then
                        need_update = true
                        break
                    end
                end
            end
        end
    end
    
    return true, need_update
end

-- 获取物品分类
local function get_item_category(item)
    local config = config_service.get_item_config(item.item_id)  
    if not config then
        return enum.ItemCategory.OTHER
    end
    return config.category or enum.ItemCategory.OTHER
end

-- 【核心功能】处理物品合成逻辑（不涉及背包）
function M.process_compose(target_id, material_items)
    -- 1. 获取合成配置
    local compose_config = config_service.get_compose_config(target_id)
    if not compose_config then
        return false, "compose config is not exist", nil, nil
    end
    
    -- 2. 验证材料是否足够
    local material_map = {}
    for _, material in ipairs(compose_config.materials) do
        material_map[material.item_id] = material.count
    end
    
    -- 检查材料
    for item_id, required_count in pairs(material_map) do
        local sufficient = false
        for _, item in ipairs(material_items) do
            if item.item_id == item_id and item.count >= required_count then
                sufficient = true
                break
            end
        end
        
        if not sufficient then
            return false, "material is not enough", nil, nil
        end
    end
    
    -- 3. 计算剩余材料
    local remain_items = {}
    for _, item in ipairs(material_items) do
        local required = material_map[item.item_id]
        if required then
            -- 创建一个新的物品表而不是使用clone函数
            local new_item = {
                id = item.id,
                user_id = item.user_id,
                item_id = item.item_id,
                count = item.count - required,
                bag_type = item.bag_type,
                slot_index = item.slot_index
            }
            
            if new_item.count > 0 then
                -- 如果材料有剩余，记录到剩余物品中
                table.insert(remain_items, new_item)
            end
        else
            -- 不需要的材料保持不变
            -- 创建一个新的物品表而不是使用clone函数
            local new_item = {
                id = item.id,
                user_id = item.user_id,
                item_id = item.item_id,
                count = item.count,
                bag_type = item.bag_type,
                slot_index = item.slot_index
            }
            table.insert(remain_items, new_item)
        end
    end
    
    -- 4. 随机判定是否成功
    local result = enum.ComposeResult.SUCCESS
    if compose_config.success_rate then
        if math.random() > compose_config.success_rate then
            result = compose_config.fail_keep_material and 
                enum.ComposeResult.FAIL or 
                enum.ComposeResult.FAIL_CONSUME
        end
    end
    
    -- 5. 创建结果物品
    local new_item = nil
    if result == enum.ComposeResult.SUCCESS then
        new_item = {
            item_id = target_id,
            count = compose_config.result_count or 1
        }
    end

    -- 6. 触发合成事件
    local event = init.get_service("event")
    skynet.send(event, "lua", "trigger_event", "on_item_composed", {
        user_id = material_items[1].user_id,
        target_id = target_id,
        result = result,
        new_item = new_item,
        consumed_materials = material_items,
        remain_materials = remain_items
    })

    return true, result, new_item, remain_items
end

-- 【核心功能】处理物品分解逻辑（不涉及背包）
function M.process_decompose(decompose_items)
    -- 1. 验证参数
    if not decompose_items or #decompose_items == 0 then
        return false, "invalid params", nil
    end

    -- 2. 获取要分解的物品
    local item = decompose_items[1]
    if not item then
        return false, "invalid decompose item", nil
    end

    -- 3. 获取分解配置
    local decompose_config = config_service.get_decompose_config(item.item_id)
    if not decompose_config then
        return false, "item is not decomposable", nil
    end

    -- 4. 构造分解结果物品
    local result_items = {}
    for _, result_item in ipairs(decompose_config.result_items) do
        -- 创建新的结果物品
        local new_item = {
            id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = item.user_id,
            item_id = result_item.item_id,
            count = result_item.count,
            bag_type = enum.BagType.BAG_TYPE_MAIN,
            slot_index = 0  -- 让背包服务分配格子
        }
        table.insert(result_items, new_item)
    end

    -- 5. 触发分解事件
    local event = init.get_service("event")
    skynet.send(event, "lua", "trigger_event", "on_item_decomposed", {
        user_id = item.user_id,  -- 添加 user_id
        item_id = item.item_id,
        count = item.count,
        result_items = result_items
    })

    -- 6. 返回结果
    return true, enum.DecomposeResult.SUCCESS, result_items
end

function M.get_special_item(user_id, item_id)
    local items = M.get_user_items(user_id)
    if not items then
        logger.error("get_special_item failed, user_id: %d, item_id: %d", user_id, item_id)
        return 0
    end
    local count = 0
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            count = count + item.count
        end
    end
    return count
end

function M.add_special_item(user_id, item_id, count, source)
    -- Parameter validation with detailed logging
    if not user_id then
        logger.error("add_special_item failed - missing user_id")
        return false
    end
    if not item_id then
        logger.error("add_special_item failed - missing item_id")
        return false
    end
    if not count or type(count) ~= "number" then
        logger.error("add_special_item failed - invalid count: %s", tostring(count))
        return false
    end
    if count <= 0 then
        logger.error("add_special_item failed - count must be positive: %d", count)
        return false
    end

    logger.info("Adding special item - user_id: %d, item_id: %d, count: %d", 
        user_id, item_id, count)

    -- Use add_items_to_slot with proper parameter structure
    local ok, err = M.add_items_to_slot(user_id, {
        item_id = item_id,
        count = count
    }, source)

    if not ok then
        logger.error("add_special_item failed - user_id: %d, item_id: %d, count: %d, error: %s",
            user_id, item_id, count, err)
        return false
    end

    -- Trigger item addition event
    local event = init.get_service("event")
    skynet.send(event, "lua", "trigger_event", "on_item_added", {
        user_id = user_id,
        item_id = item_id,
        count = count
    })

    return true
end

-- 消耗物品 (扣除指定数量的物品)
function M.consume_item(user_id, item_id, count, source)
    if not user_id or not item_id or not count or count <= 0 then
        return false, "invalid parameters"
    end
    
    -- 设置默认来源
    source = source or enum.ChangeSource.SOURCE_CONSUME
    
    -- 获取用户物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        logger.error("Failed to get items for user %d", user_id)
        return false, "failed to get items"
    end
    
    -- 计算用户拥有的物品总数
    local owned_count = 0
    local target_items = {}
    
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            owned_count = owned_count + item.count
            table.insert(target_items, item)
        end
    end
    
    -- 检查数量是否足够
    if owned_count < count then
        logger.warn("User %d doesn't have enough items. Required: %d, Owned: %d",
                   user_id, count, owned_count)
        return false, "not enough items"
    end
    
    -- 扣除物品
    local remaining = count
    
    for _, item in ipairs(target_items) do
        if remaining <= 0 then
            break
        end
        
        if item.count <= remaining then
            -- 完全消耗这个堆叠物品
            remaining = remaining - item.count
            item.count = 0
        else
            -- 部分消耗
            item.count = item.count - remaining
            remaining = 0
        end
    end
    
    -- 清理count为0的物品
    local updated_items = {}
    for _, item in ipairs(items) do
        if item.count > 0 then
            table.insert(updated_items, item)
        end
    end
    
    -- 保存更新后的物品列表
    local ok = item_dao.update_user_items(user_id, updated_items)
    if not ok then
        logger.error("Failed to update items after consuming for user %d", user_id)
        return false, "failed to update items"
    end
    
    -- 记录物品变化
    item_dao.log_change(user_id, item_id, count,
        enum.ChangeType.CHANGE_TYPE_REDUCE, source,
        owned_count, owned_count - count)
    
    -- 触发物品消耗事件
    local event = init.get_service("event")
    skynet.send(event, "lua", "trigger_event", "on_item_consumed", {
        user_id = user_id,
        item_id = item_id,
        count = count,
        remain_count = owned_count - count,
        source = source
    })
    
    return true
end

-- 按类型获取用户物品
function M.get_user_items_by_type(user_id, item_type)
    if not user_id then
        return nil, "Invalid user id"
    end
    
    if not item_type then
        return nil, "Invalid item type"
    end
    
    logger.debug("Getting items of type %d for user %d", item_type, user_id)
    
    -- 获取用户所有物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        logger.error("Failed to get items for user: %d", user_id)
        return {}
    end
    
    -- 筛选指定类型的物品
    local result = {}
    local configs = table_service.get_item_configs()
    
    for _, item in ipairs(items) do
        local config = configs[item.item_id]
        if config and config.type == item_type then
            table.insert(result, item)
        end
    end
    
    logger.debug("Found %d items of type %d for user %d", #result, item_type, user_id)
    return result
end

-- 检查物品是否足够
function M.check_items_enough(user_id, items)
    if not user_id or not items then
        return false, "invalid params"
    end
    
    -- 获取用户物品列表
    local user_items = M.get_user_items(user_id)
    if not user_items then
        return false, "get items failed"
    end
    
    -- 统计用户物品数量
    local item_counts = {}
    for _, item in ipairs(user_items) do
        item_counts[item.item_id] = (item_counts[item.item_id] or 0) + item.count
    end
    
    -- 检查每个物品是否足够
    local items_info = {}
    for _, need_item in ipairs(items) do
        local item_id = need_item.item_id
        local need_count = need_item.count or 1
        local have_count = item_counts[item_id] or 0
        
        items_info[item_id] = {
            current_count = have_count,
            need_count = need_count
        }
        
        if have_count < need_count then
            logger.error("Not enough item: user_id=%d, item_id=%d, current=%d, need=%d",
                user_id, item_id, have_count, need_count)
            return false, items_info
        end
    end
    
    return true, items_info
end

-- 消耗物品
function M.consume_items(user_id, items, source)
    if not user_id or not items then
        return false, "invalid params"
    end
    
    -- 获取用户物品列表
    local user_items = M.get_user_items(user_id)
    if not user_items then
        return false, "get items failed"
    end
    
    -- 检查物品是否足够
    local has_enough, items_info = M.check_items_enough(user_id, items)
    if not has_enough then
        return false, "not enough items"
    end
    
    -- 记录消耗的物品
    local consumed_items = {}
    
    -- 消耗物品
    for _, need_item in ipairs(items) do
        local item_id = need_item.item_id
        local need_count = need_item.count or 1
        local remain_count = need_count
        
        -- 遍历用户物品列表，扣除物品
        for i = #user_items, 1, -1 do
            local item = user_items[i]
            if item.item_id == item_id and remain_count > 0 then
                local before_count = item.count
                local consume_count = math.min(remain_count, item.count)
                
                item.count = item.count - consume_count
                remain_count = remain_count - consume_count
                
                -- 记录物品变化
                item_dao.log_change(user_id, item_id, consume_count,
                    enum.ChangeType.CHANGE_TYPE_REDUCE, source,
                    before_count, item.count)
                
                -- 记录消耗的物品
                table.insert(consumed_items, {
                    item_id = item_id,
                    count = consume_count
                })
                
                -- 如果物品数量为0，从列表中移除
                if item.count <= 0 then
                    table.remove(user_items, i)
                end
                
                if remain_count <= 0 then
                    break
                end
            end
        end
    end
    
    -- 保存更新后的物品列表
    local ok = item_dao.update_user_items(user_id, user_items)
    if not ok then
        return false, "save items failed"
    end
    
    return true, consumed_items
end

-- 获取物品数量
function M.get_item_count(user_id, item_id)
    if not user_id or not item_id then
        return 0
    end
    
    -- 获取用户物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return 0
    end
    
    -- 统计指定物品的总数量
    local total_count = 0
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            total_count = total_count + item.count
        end
    end
    
    return total_count
end

return M 