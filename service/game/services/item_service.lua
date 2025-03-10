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

local M = {}

-- 物品查询条件
local QUERY_CONDITION = {
    TYPE = 1,       -- 按类型查询
    QUALITY = 2,    -- 按品质查询
    LEVEL = 3,      -- 按等级查询
    EXPIRED = 4,    -- 按过期状态查询
    LOCKED = 5,     -- 按锁定状态查询
    NAME = 6,       -- 按名称查询
    TAG = 7,        -- 按标签查询
    EFFECT = 8,     -- 按效果查询
    CATEGORY = 9    -- 按分类查询
}

-- 排序规则
local SORT_RULE = {
    TYPE = 1,       -- 按类型排序
    QUALITY = 2,    -- 按品质排序
    LEVEL = 3,      -- 按等级排序
    COUNT = 4,      -- 按数量排序
    TIME = 5        -- 按时间排序
}

-- 初始化新用户物品
function M.init_user_items(user_id)
    if not user_id then
        return false, "invalid user id"
    end

    logger.info("Initializing items for user: %d", user_id)

    -- 1. 创建主背包
    local bag = bag_dao.get_user_bag(user_id, enum.BagType.BAG_TYPE_MAIN)
    if not bag then
        bag = bag_dao.create_bag(user_id, enum.BagType.BAG_TYPE_MAIN, 20)  -- 默认20格
        if not bag then
            return false, "create bag failed"
        end
    end

    -- 2. 添加默认物品
    local default_items = config_service.get_initial_items()
    if #default_items > 0 then
        local ok, err = M.add_items_to_slot(user_id, default_items, enum.ChangeSource.SOURCE_INIT)
        if not ok then
            logger.error("Failed to add default items for user %d: %s", user_id, err)
            return false, err
        end
    end

    return true
end

-- 获取物品排序权重
local function get_item_weight(item, rule)
    local config = config_service.get_item_config(item.item_id)
    if not config then
        return 0
    end
    
    if rule == SORT_RULE.TYPE then
        return config.type * 10000 + config.quality * 100 + config.level
    elseif rule == SORT_RULE.QUALITY then
        return config.quality * 10000 + config.level * 100 + config.type
    elseif rule == SORT_RULE.LEVEL then
        return config.level * 10000 + config.quality * 100 + config.type
    elseif rule == SORT_RULE.COUNT then
        return item.count * 10000 + config.quality * 100 + config.type
    elseif rule == SORT_RULE.TIME then
        return (os.time() - item.create_time) * 10000 + config.type * 100 + config.quality
    end
    return 0
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
    
    -- 3. 找到已使用的槽位
    local used_slots = {}
    for _, item in ipairs(existing_items) do
        if item.bag_type == bag_type then
            used_slots[item.slot_index] = true
        end
    end
    
    -- 处理每个物品
    local all_successful = true
    local error_message = nil
    
    for _, item_data in ipairs(items_array) do
        local item_id = item_data.item_id
        local count = item_data.count or 1
        
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
                for i = 0, bag.size - 1 do
                    if not used_slots[i] then
                        empty_slot = i
                        used_slots[i] = true  -- 标记为已使用
                        break
                    end
                end
                
                if not empty_slot then
                    logger.error("No empty slot found for infinite stack item")
                    all_successful = false
                    error_message = "bag is full"
                    break
                end
                
                -- 创建新物品
                local new_item = item_model.new({
                    id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
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
                for i = 0, bag.size - 1 do
                    if not used_slots[i] then
                        empty_slot = i
                        used_slots[i] = true  -- 标记为已使用
                        break
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
                
                -- 创建新物品
                local new_item = item_model.new({
                    id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
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
    logger.info("items: %s", utils.table_to_string(items))
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

-- 过滤物品列表
local function filter_items(items, conditions)
    if not conditions or #conditions == 0 then
        return items
    end
    
    local result = {}
    for _, item in ipairs(items) do
        local match = true
        for _, condition in ipairs(conditions) do
            local config = config_service.get_item_config(item.item_id)
            if not config then
                match = false
                break
            end
            
            if condition.type == QUERY_CONDITION.TYPE then
                if config.type ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.QUALITY then
                if config.quality ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.LEVEL then
                if config.level < condition.min or config.level > condition.max then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.EXPIRED then
                if check_item_expired(item) ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.LOCKED then
                local locked = (item.lock_type ~= item_model.LOCK_TYPE.NONE)
                if locked ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.TAG then
                if not check_item_tags(item, condition.tags) then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.CATEGORY then
                if get_item_category(item) ~= condition.value then
                    match = false
                    break
                end
            end
        end
        
        if match then
            table.insert(result, item)
        end
    end
    
    return result
end

-- 查询用户物品
function M.query_user_items(user_id, conditions)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return {}
    end
    
    -- 2. 应用过滤条件
    local filtered = filter_items(items, conditions)
    
    -- 3. 按条件排序
    if conditions and conditions.sort_by then
        table.sort(filtered, function(a, b)
            local config_a = config_service.get_item_config(a.item_id)
            local config_b = config_service.get_item_config(b.item_id)
            
            if conditions.sort_by == "quality" then
                if config_a.quality == config_b.quality then
                    return a.item_id < b.item_id
                end
                return config_a.quality > config_b.quality
            elseif conditions.sort_by == "level" then
                if config_a.level == config_b.level then
                    return a.item_id < b.item_id
                end
                return config_a.level > config_b.level
            elseif conditions.sort_by == "count" then
                if a.count == b.count then
                    return a.item_id < b.item_id
                end
                return a.count > b.count
            end
            
            return a.item_id < b.item_id
        end)
    end
    
    return filtered
end

-- 统计物品数量
function M.count_user_items(user_id, conditions)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return 0
    end
    
    -- 2. 应用过滤条件
    local filtered = filter_items(items, conditions)
    
    -- 3. 统计数量
    local total_count = 0
    for _, item in ipairs(filtered) do
        total_count = total_count + item.count
    end
    
    return total_count
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

-- 搜索物品
function M.search_items(user_id, keyword, options)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return {}
    end
    
    -- 2. 准备搜索选项
    options = options or {}
    local result = {}
    
    -- 3. 遍历物品
    for _, item in ipairs(items) do
        local config = config_service.get_item_config(item.item_id)  
        if config then
            local match = false
            
            -- 按名称搜索
            if options.search_name then
                if string.find(config.name, keyword) then
                    match = true
                end
            end
            
            -- 按描述搜索
            if options.search_desc and config.description then
                if string.find(config.description, keyword) then
                    match = true
                end
            end
            
            -- 按标签搜索
            if options.search_tag and config.tags then
                for _, tag in ipairs(config.tags) do
                    if string.find(tag, keyword) then
                        match = true
                        break
                    end
                end
            end
            
            -- 按效果搜索
            if options.search_effect and config.effects then
                for _, effect in ipairs(config.effects) do
                    if string.find(effect.description, keyword) then
                        match = true
                        break
                    end
                end
            end
            
            if match then
                table.insert(result, item)
            end
        end
    end
    
    -- 4. 应用过滤条件
    if options.conditions then
        result = filter_items(result, options.conditions)
    end
    
    -- 5. 应用排序
    if options.sort_by then
        table.sort(result, function(a, b)
            local config_a = config_service.get_item_config(a.item_id)   
            local config_b = config_service.get_item_config(b.item_id)
            
            if options.sort_by == "name" then
                return config_a.name < config_b.name
            elseif options.sort_by == "quality" then
                if config_a.quality == config_b.quality then
                    return config_a.name < config_b.name
                end
                return config_a.quality > config_b.quality
            elseif options.sort_by == "count" then
                if a.count == b.count then
                    return config_a.name < config_b.name
                end
                return a.count > b.count
            end
            
            return config_a.name < config_b.name
        end)
    end
    
    -- 6. 应用分页
    if options.page and options.page_size then
        local start = (options.page - 1) * options.page_size + 1
        local finish = start + options.page_size - 1
        local paged = {}
        for i = start, finish do
            if result[i] then
                table.insert(paged, result[i])
            end
        end
        result = paged
    end
    
    return result
end

-- 检查物品标签
local function check_item_tags(item, tags)
    local config = config_service.get_item_config(item.item_id)  
    if not config or not config.tags then
        return false
    end
    
    -- 转换配置标签为集合
    local tag_set = {}
    for _, tag in ipairs(config.tags) do
        tag_set[tag] = true
    end
    
    -- 检查是否包含所有指定标签
    for _, tag in ipairs(tags) do
        if not tag_set[tag] then
            return false
        end
    end
    
    return true
end

-- 获取物品分类
local function get_item_category(item)
    local config = config_service.get_item_config(item.item_id)  
    if not config then
        return enum.ItemCategory.OTHER
    end
    return config.category or enum.ItemCategory.OTHER
end

-- 按分类获取物品
function M.get_items_by_category(user_id, category)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return {}
    end
    
    -- 2. 过滤指定分类的物品
    local result = {}
    for _, item in ipairs(items) do
        if get_item_category(item) == category then
            table.insert(result, item)
        end
    end
    
    return result
end

-- 获取物品标签
function M.get_item_tags(item_id)
    local config = config_service.get_item_config(item_id)   
    if not config then
        return {}
    end
    return config.tags or {}
end

-- 装备物品
function M.equip_item(user_id, item_id, slot_id)
    -- 1. 获取物品
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 2. 查找物品
    local item = nil
    for _, it in ipairs(items) do
        if it.item_id == item_id then
            item = it
            break
        end
    end
    
    if not item then
        return false, "item is not exist"
    end
    
    -- 3. 检查物品类型
    local config = config_service.get_item_config(item_id)   
    if not config or config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    
    -- 4. 检查装备槽位
    if not config.equip_slot or config.equip_slot ~= slot_id then
        return false, "equip slot is not match"
    end
    
    -- 5. 获取装备栏
    local equip_bag = bag_dao.get_user_bag(user_id, enum.BagType.BAG_TYPE_EQUIP)  -- 直接使用 dao 层
    if not equip_bag then
        return false, "get equip bag failed"
    end
    
    -- 6. 检查等级限制
    if config.level_required then
        -- TODO
    end
    
    -- 7. 卸下当前装备
    local current_equip = equip_bag.slots[slot_id]
    if current_equip and current_equip.state == enum.SlotState.SLOT_STATE_OCCUPIED then
        -- 移动到背包
        local ok, err = M.unequip_item(user_id, slot_id)
        if not ok then
            return false, err
        end
    end
    
    -- 8. 装备新物品
    equip_bag.slots[slot_id] = {
        index = slot_id,
        state = enum.SlotState.SLOT_STATE_OCCUPIED,
        item_id = item_id,
        count = 1,
        equip_time = os.time()
    }
    
    -- 9. 从背包移除
    item.count = item.count - 1
    if item.count <= 0 then
        for i, it in ipairs(items) do
            if it.item_id == item_id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 10. 保存更新
    local ok = bag_dao.update_user_bag(user_id, enum.BagType.BAG_TYPE_EQUIP, equip_bag)
    if not ok then
        return false, "save equip bag failed"
    end
    
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 11. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true
end

-- 卸下装备
function M.unequip_item(user_id, slot_id)
    -- 1. 获取装备栏
    local equip_bag = bag_dao.get_user_bag(user_id, enum.BagType.BAG_TYPE_EQUIP)  -- 直接使用 dao 层
    if not equip_bag then
        return false, "get equip bag failed"
    end
    
    -- 2. 检查装备槽位
    local equip = equip_bag.slots[slot_id]
    if not equip or equip.state ~= enum.SlotState.SLOT_STATE_OCCUPIED then
        return false, "equip slot is empty"
    end
    
    -- 3. 添加到背包
    local ok, err = M.add_items_to_slot(user_id, {
        {
            item_id = equip.item_id,
            count = 1
        }
    }, enum.ChangeSource.SOURCE_UNEQUIP)
    if not ok then
        return false, err
    end
    
    -- 4. 清空装备槽位
    equip_bag.slots[slot_id] = {
        index = slot_id,
            state = enum.SlotState.SLOT_STATE_EMPTY
    }
    
    -- 5. 保存更新
    ok = bag_dao.update_user_bag(user_id, enum.BagType.BAG_TYPE_EQUIP, equip_bag)
    if not ok then
        return false, "save equip bag failed"
    end
    
    -- 6. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true
end

-- 获取装备强化配置
local function get_enhance_config(level)
    local config = require("config.enhance_config")[level]
    if not config then
        return nil
    end
    return config
end

-- 强化装备
function M.enhance_equipment(user_id, equip_id, material_list, protect_item)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "equip is not exist"
    end
    
    -- 3. 检查装备类型
    local config = config_service.get_item_config(equip.item_id) 
    if not config or config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    
    -- 4. 获取强化配置
    local enhance_level = equip.enhance_level or 0
    local enhance_config = get_enhance_config(enhance_level + 1)
    if not enhance_config then
        return false, "has reached the max enhance level"
    end
    
    -- 5. 检查材料
    local materials = {}
    local total_exp = 0
    for _, material in ipairs(material_list) do
        local mat_config = config_service.get_item_config(material.item_id)
        if not mat_config then
            return false, "material config is not exist"
        end
        
        if not mat_config.enhance_exp then
            return false, "item cannot be used as enhance material"
        end
        
        total_exp = total_exp + mat_config.enhance_exp * material.count
        table.insert(materials, material)
    end
    
    if total_exp < enhance_config.need_exp then
        return false, "enhance exp is not enough"
    end
    
    -- 6. 移除材料
    local ok, err = M.batch_remove_items(user_id, materials)
    if not ok then
        return false, err
    end
    
    -- 7. 计算强化结果
    local result = enum.EnhanceResult.SUCCESS
    local enhance_type = enum.EnhanceType.NORMAL
    local random = math.random()
    
    if random <= enhance_config.perfect_rate then
        enhance_type = enum.EnhanceType.PERFECT
    elseif random <= enhance_config.success_rate then
        enhance_type = enum.EnhanceType.LUCKY
    else
        -- 失败处理
        if protect_item then
            -- 使用保护道具
            local ok, err, result_items = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                -- 返还材料
                M.add_items_to_slot(user_id, materials, enum.ChangeSource.SOURCE_ENHANCE)
                return false, err
            end
            result = enum.EnhanceResult.FAIL
        else
            -- 随机失败结果
            if random <= enhance_config.break_rate then
                result = enum.EnhanceResult.BREAK
            elseif random <= enhance_config.down_rate then
                result = enum.EnhanceResult.FAIL_DOWN
            else
                result = enum.EnhanceResult.FAIL
            end
        end
    end
    
    -- 8. 应用强化结果
    if result == enum.EnhanceResult.SUCCESS or 
        result == enum.EnhanceResult.PERFECT or
        result == enum.EnhanceResult.LUCKY then
        -- 升级强化等级
        equip.enhance_level = enhance_level + 1
        
        -- 更新属性
        local props = {}
        for prop_type, base_value in pairs(config.base_props or {}) do
            local enhance_ratio = enhance_config.prop_ratio
            if enhance_type == enum.EnhanceType.PERFECT then
                enhance_ratio = enhance_ratio * 1.5
            elseif enhance_type == enum.EnhanceType.LUCKY then
                enhance_ratio = enhance_ratio * 1.2
            end
            props[prop_type] = math.floor(base_value * enhance_ratio)
        end
        equip.enhance_props = props
        
    elseif result == enum.EnhanceResult.FAIL_DOWN then
        -- 降级
        equip.enhance_level = math.max(0, enhance_level - 1)
        
    elseif result == enum.EnhanceResult.BREAK then
        -- 装备破碎
        for i, item in ipairs(items) do
            if item.id == equip_id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 9. 保存更新
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 10. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        enhance_type = enhance_type,
        equip = equip
    }
end

-- 获取装备精炼配置
local function get_refine_config(level)
    local config = require("config.refine_config")[level]
    if not config then
        return nil
    end
    return config
end

-- 精炼装备
function M.refine_equipment(user_id, equip_id, material_list, protect_item)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "equip is not exist"
    end
    
    -- 3. 检查装备类型
    local config = config_service.get_item_config(equip.item_id) 
    if not config or config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    
    -- 4. 获取精炼配置
    local refine_level = equip.refine_level or 0
    local refine_config = get_refine_config(refine_level + 1)
    if not refine_config then
        return false, "has reached the max refine level"
    end
    
    -- 5. 检查材料
    local materials = {}
    local total_exp = 0
    for _, material in ipairs(material_list) do
        local mat_config = config_service.get_item_config(material.item_id)
        if not mat_config then
            return false, "material config is not exist"
        end
        
        if not mat_config.refine_exp then
            return false, "item cannot be used as refine material"
        end
        
        total_exp = total_exp + mat_config.refine_exp * material.count
        table.insert(materials, material)
    end
    
    if total_exp < refine_config.need_exp then
        return false, "refine exp is not enough"
    end
    
    -- 6. 移除材料
    local ok, err = M.batch_remove_items(user_id, materials)
    if not ok then
        return false, err
    end
    
    -- 7. 计算精炼结果
    local result = enum.RefineResult.SUCCESS
    local random = math.random()
    
    if random > refine_config.success_rate then
        -- 失败处理
        if protect_item then
            -- 使用保护道具
            local ok, err, result_items = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                -- 返还材料
                M.add_items_to_slot(user_id, materials, enum.ChangeSource.SOURCE_REFINE)
                return false, err
            end
            result = enum.RefineResult.FAIL
        else
            -- 随机失败结果
            if random <= refine_config.break_rate then
                result = enum.RefineResult.BREAK
            elseif random <= refine_config.down_rate then
                result = enum.RefineResult.FAIL_DOWN
            else
                result = enum.RefineResult.FAIL
            end
        end
    end
    
    -- 8. 应用精炼结果
    if result == enum.RefineResult.SUCCESS then
        -- 升级精炼等级
        equip.refine_level = refine_level + 1
        
        -- 更新属性
        local props = {}
        for prop_type, base_value in pairs(config.base_props or {}) do
            local refine_ratio = refine_config.prop_ratio
            props[prop_type] = math.floor(base_value * refine_ratio)
        end
        equip.refine_props = props
        
    elseif result == enum.RefineResult.FAIL_DOWN then
        -- 降级
        equip.refine_level = math.max(0, refine_level - 1)
        
    elseif result == enum.RefineResult.BREAK then
        -- 装备破碎
        for i, item in ipairs(items) do
            if item.id == equip_id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 9. 保存更新
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 10. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 洗练装备
function M.reforge_equipment(user_id, equip_id, material_list)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "equip is not exist"
    end
    
    -- 3. 检查装备类型
    local config = config_service.get_item_config(equip.item_id) 
    if not config or config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    
    -- 4. 检查材料
    local materials = {}
    local reforge_power = 0
    for _, material in ipairs(material_list) do
        local mat_config = config_service.get_item_config(material.item_id)
        if not mat_config then
            return false, "material config is not exist"
        end
        
        if not mat_config.reforge_power then
            return false, "item cannot be used as reforge material"
        end
        
        reforge_power = reforge_power + mat_config.reforge_power * material.count
        table.insert(materials, material)
    end
    
    -- 5. 移除材料
    local ok, err = M.batch_remove_items(user_id, materials)
    if not ok then
        return false, err
    end
    
    -- 6. 计算洗练结果
    local result = enum.ReforgeResult.SUCCESS
    local random = math.random()
    local perfect_rate = math.min(0.3, reforge_power * 0.01)
    
    if random <= perfect_rate then
        result = enum.ReforgeResult.PERFECT
    elseif random > 0.7 then
        result = enum.ReforgeResult.FAIL
    end
    
    -- 7. 生成新属性
    local new_props = {}
    if result ~= enum.ReforgeResult.FAIL then
        -- 保留固定属性
        for prop_type, value in pairs(equip.props or {}) do
            if config.fixed_props and config.fixed_props[prop_type] then
                new_props[prop_type] = value
            end
        end
        
        -- 随机新属性
        local random_prop_count = result == enum.ReforgeResult.PERFECT and 3 or 2
        for i = 1, random_prop_count do
            local prop_type = config.random_props[math.random(#config.random_props)]
            local base_value = config.prop_ranges[prop_type]
            local value = math.random(base_value[1], base_value[2])
            new_props[prop_type] = value
        end
        
        -- 特殊属性(完美洗练)
        if result == enum.ReforgeResult.PERFECT and config.special_props then
            local special_prop = config.special_props[math.random(#config.special_props)]
            new_props[special_prop.type] = special_prop.value
        end
    end
    
    -- 8. 应用洗练结果
    if result ~= enum.ReforgeResult.FAIL then
        equip.props = new_props
        equip.reforge_count = (equip.reforge_count or 0) + 1
    end
    
    -- 9. 保存更新
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 10. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 镶嵌宝石
function M.inlay_gem(user_id, equip_id, gem_id, slot_index, protect_item)
    -- 1. 获取装备和宝石
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 2. 查找装备和宝石
    local equip, gem = nil, nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
        elseif item.id == gem_id then
            gem = item
        end
    end
    
    if not equip then
        return false, "equip is not exist"
    end
    if not gem then
        return false, "gem is not exist"
    end
    
    -- 3. 检查装备和宝石类型
    local equip_config = config_service.get_item_config(equip.item_id)   
    local gem_config = config_service.get_item_config(gem.item_id)
    
    if not equip_config or equip_config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    if not gem_config or gem_config.type ~= enum.ItemType.ITEM_TYPE_GEM then
        return false, "item is not gem"
    end
    
    -- 4. 检查槽位
    if not equip.gem_slots then
        equip.gem_slots = {}
    end
    
    if not equip.gem_slots[slot_index] then
        return false, "slot is not exist"
    end
    
    if equip.gem_slots[slot_index].state ~= enum.GemSlotState.EMPTY then
        return false, "slot is occupied"
    end
    
    -- 5. 检查宝石等级限制
    if gem_config.level_required and gem_config.level_required > equip_config.level then
        return false, "equip level is not enough"
    end
    
    -- 6. 计算镶嵌结果
    local result = enum.GemResult.SUCCESS
    local random = math.random()
    
    if random > gem_config.inlay_rate then
        -- 失败处理
        if protect_item then
            -- 使用保护道具
            local ok, err, result_items = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                return false, err
            end
            result = enum.GemResult.FAIL
        else
            result = enum.GemResult.BREAK
        end
    end
    
    -- 7. 应用镶嵌结果
    if result == enum.GemResult.SUCCESS then
        -- 移除宝石
        gem.count = gem.count - 1
        if gem.count <= 0 then
            for i, item in ipairs(items) do
                if item.id == gem_id then
                    table.remove(items, i)
                    break
                end
            end
        end
        
        -- 镶嵌到装备
        equip.gem_slots[slot_index] = {
            state = enum.GemSlotState.OCCUPIED,
            gem_id = gem.item_id,
            inlay_time = os.time()
        }
        
        -- 更新装备属性
        if not equip.gem_props then
            equip.gem_props = {}
        end
        
        for prop_type, value in pairs(gem_config.props or {}) do
            equip.gem_props[prop_type] = (equip.gem_props[prop_type] or 0) + value
        end
        
    elseif result == enum.GemResult.BREAK then
        -- 宝石破碎
        gem.count = gem.count - 1
        if gem.count <= 0 then
            for i, item in ipairs(items) do
                if item.id == gem_id then
                    table.remove(items, i)
                    break
                end
            end
        end
    end
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 9. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 卸下宝石
function M.remove_gem(user_id, equip_id, slot_index, protect_item)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "get item failed"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "equip is not exist"
    end
    
    -- 3. 检查槽位
    if not equip.gem_slots or not equip.gem_slots[slot_index] then
        return false, "slot is not exist"
    end
    
    local slot = equip.gem_slots[slot_index]
    if slot.state ~= enum.GemSlotState.OCCUPIED then
        return false, "slot is not occupied"
    end
    
    -- 4. 计算卸下结果
    local result = enum.GemResult.SUCCESS
    local random = math.random()
    
    if random > 0.7 then  -- 30%概率失败
        if protect_item then
            -- 使用保护道具
            local ok, err, result_items = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                return false, err
            end
            result = enum.GemResult.FAIL
        else
            result = enum.GemResult.BREAK
        end
    end
    
    -- 5. 应用卸下结果
    if result == enum.GemResult.SUCCESS then
        -- 返还宝石
        local ok, err = M.add_items_to_slot(user_id, {
            {
                item_id = slot.gem_id,
                count = 1
            }
        }, enum.ChangeSource.SOURCE_REMOVE_GEM)
        if not ok then
            return false, err
        end
    end
    
    -- 6. 清空槽位
    equip.gem_slots[slot_index] = {
        state = enum.GemSlotState.EMPTY
    }
    
    -- 7. 更新装备属性
    local gem_config = config_service.get_item_config(slot.gem_id)
    if gem_config and gem_config.props then
        for prop_type, value in pairs(gem_config.props) do
            if equip.gem_props then
                equip.gem_props[prop_type] = (equip.gem_props[prop_type] or 0) - value
                if equip.gem_props[prop_type] <= 0 then
                    equip.gem_props[prop_type] = nil
                end
            end
        end
    end
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 9. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 检查物品是否可装备
local function can_equip(item_id, slot_index)
    local config = config_service.get_item_config(item_id)
    if not config then
        return false
    end
    
    -- 检查物品类型
    if config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false
    end
    
    -- 检查装备类型与槽位是否匹配
    return config.equip_type == slot_index
end

-- 创建新物品
function M.create_item(user_id, item_id, count)
    if not user_id or not item_id or not count or count <= 0 then
        return nil, "invalid params"
    end
    
    -- 检查物品配置是否存在
    local config = config_service.get_item_config(item_id)
    if not config then
        return nil, "item is not exist"
    end
    
    -- 创建物品对象
    local item = item_model.new({
        id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
        user_id = user_id,
        item_id = item_id,
        count = count
    })
    
    -- 记录物品变化
    item_dao.log_change(user_id, item_id, count,
        enum.ChangeType.CHANGE_TYPE_ADD, enum.ChangeSource.SOURCE_CREATE,
        0, count)
    
    return item
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
function M.consume_item(user_id, item_id, count)
    if not user_id or not item_id or not count or count <= 0 then
        return false, "invalid parameters"
    end
    
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
    
    -- 触发物品消耗事件
    local event = init.get_service("event")
    skynet.send(event, "lua", "trigger_event", "on_item_consumed", {
        user_id = user_id,
        item_id = item_id,
        count = count,
        remain_count = owned_count - count
    })
    
    -- 清除缓存
    cache.remove_user_items(user_id)
    
    return true
end

return M 