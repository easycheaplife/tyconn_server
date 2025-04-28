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
    local default_items = table_service.get_initial_items()
    if #default_items > 0 then
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
    local config = table_service.get_item_config(item_id)
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

-- 添加物品到指定格子（新方法 - 单条记录操作版本）
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
    
    -- 2. 获取物品列表 (使用传入的列表或从数据库查询)
    local current_items = item_dao.get_user_items(user_id) or {}
    -- 3. 找到已使用的槽位和已存在的物品
    local used_slots = {}
    local slot_item_map = {} -- 用于存储slot_index对应的物品
    local item_map = {}      -- 用于按物品ID快速查找物品列表
    
    for _, item in ipairs(current_items) do
        if item.bag_type == bag_type then
            used_slots[item.slot_index] = true
            slot_item_map[item.slot_index] = item
        end
        
        -- 按物品ID组织物品列表，便于堆叠检查
        if not item_map[item.item_id] then
            item_map[item.item_id] = {}
        end
        table.insert(item_map[item.item_id], item)
    end
    
    -- 处理每个物品
    local all_successful = true
    local error_message = nil
    local added_items = {} -- 记录新添加或更新的物品
    
    for _, item_data in ipairs(items_array) do
        local item_id = item_data.item_id
        local count = item_data.count or 1
        local slot_index = item_data.slot_index -- 如果指定了格子
        
        logger.info("Processing item_id: %d, count: %d", item_id, count)
        
        -- 4. 获取物品配置
        local config = table_service.get_item_config(item_id)
        if not config then
            logger.error("Item config not found for item_id: %d", item_id)
            all_successful = false
            error_message = "item config not found"
            break
        end
        
        -- 5. 处理堆叠逻辑
        local remaining_count = count
        local stack_limit = config.max_stack or 999999
        
        -- 5.1 尝试堆叠到已有物品
        if item_map[item_id] then
            for _, existing_item in ipairs(item_map[item_id]) do
                if remaining_count <= 0 then
                    break
                end
                
                if existing_item.bag_type == bag_type then
                    -- 堆叠物品
                    local old_count = existing_item.count
                    
                    -- 检查是否有堆叠限制
                    local can_add = math.min(remaining_count, stack_limit - existing_item.count)
                    
                    if can_add > 0 then
                        -- 更新单条记录
                        existing_item.count = existing_item.count + can_add
                        existing_item.update_time = os.time()
                        
                        -- 保存单条物品记录更新
                        local ok = item_dao.update_single_item(existing_item)
                        if not ok then
                            logger.error("Failed to update stacked item for user %d, item_id %d", 
                                user_id, item_id)
                            all_successful = false
                            error_message = "update item failed"
                            break
                        end
                        
                        -- 记录物品增加日志
                        item_dao.log_change(user_id, item_id, can_add,
                            enum.ChangeType.CHANGE_TYPE_ADD, source,
                            old_count, existing_item.count)
                            
                        -- 记录更新的物品
                        table.insert(added_items, existing_item)
                        
                        remaining_count = remaining_count - can_add
                    end
                end
            end
        end
        
        -- 如果操作失败，跳出循环
        if not all_successful then
            break
        end
        
        -- 5.2 如果还有剩余，创建新物品
        while remaining_count > 0 do
            -- 找一个空格子
            local available_slot = nil
            if slot_index and not used_slots[slot_index] then
                -- 如果指定了格子且未被使用
                available_slot = slot_index
            else
                -- 自动寻找空格子
                for i = 0, bag.size - 1 do
                    if not used_slots[i] then
                        available_slot = i
                        break
                    end
                end
            end
            
            if not available_slot then
                -- 背包已满
                logger.error("No available slot in bag for user %d", user_id)
                all_successful = false
                error_message = "bag is full"
                break
            end
            
            -- 计算放入当前格子的数量
            local add_count = math.min(remaining_count, stack_limit)
            
            -- 生成唯一的物品ID
            local new_item_id = snowflake.next_id(snowflake.ID_TYPE.ITEM)
            
            -- 创建新物品
            local new_item = {
                id = new_item_id,
                user_id = user_id,
                item_id = item_id,
                count = add_count,
                bag_type = bag_type,
                slot_index = available_slot,
                create_time = os.time(),
                update_time = os.time()
            }
            
            -- 保存单条新物品记录
            local ok = item_dao.add_single_item(new_item)
            if not ok then
                logger.error("Failed to add new item for user %d, item_id %d", 
                    user_id, item_id)
                all_successful = false
                error_message = "add item failed"
                break
            end
            
            -- 将新物品加入到当前物品列表
            table.insert(current_items, new_item)
            
            -- 记录新添加的物品
            table.insert(added_items, new_item)
            
            -- 标记格子已使用
            used_slots[available_slot] = true
            
            -- 更新剩余数量
            remaining_count = remaining_count - add_count
            
            -- 记录物品新增日志
            item_dao.log_change(user_id, item_id, add_count,
                enum.ChangeType.CHANGE_TYPE_ADD, source,
                0, add_count)
        end
    end
    
    -- 如果操作失败，返回错误
    if not all_successful then
        return false, error_message
    end
    
    -- 返回成功与更新后的物品列表
    return true, nil, added_items, current_items
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

-- 使用物品（单记录操作版本）
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
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            target_item = item
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
    
    -- 使用consume_items接口消耗物品
    local ok, consumed_items = M.consume_items(user_id, {
        {
            item_id = item_id,
            count = count
        }
    }, enum.ChangeSource.SOURCE_USE)
    
    if not ok then
        logger.error("Failed to consume item - user_id: %d, item_id: %d, count: %d", 
            user_id, item_id, count)
        return false, 'consume item failed', {}
    end

    -- 备份物品信息用于返回
    local result_item = {
        item_id = item_id,
        count = target_item.count - count
    }

    -- 应用物品效果
    local effect_ok, err, effect_items = apply_item_effect(user_id, item_id, count, enum.ChangeSource.SOURCE_USE)
    if not effect_ok then
        logger.error("Failed to apply item effect - user_id: %d, item_id: %d, error: %s",
            user_id, item_id, err)
        return false, 'item effect failed', {}
    end

    -- 记录操作日志
    logger.info("Used item (new method) - user_id: %d, item_id: %d, count: %d, remain: %d",
        user_id, item_id, count, target_item.count - count)

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
    local config = table_service.get_item_config(item.item_id)
    if not config then
        return false, "item config is not exist"
    end
    
    -- 3. 检查堆叠数量
    if config.max_stack and item.count > config.max_stack then
        return false, "exceed max stack count"
    end
    
    return true
end

-- 批量移除物品
function M.batch_remove_items(user_id, item_list, source)
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
    
    -- 4. 逐个移除物品
    for _, item_info in ipairs(item_list) do
        local ok, err = M.consume_item(user_id, item_info.item_id, item_info.count, source)
        if not ok then
            -- 如果移除失败，需要回滚已移除的物品
            for i = 1, #item_list do
                if i < #item_list then
                    -- 对于已移除的物品，重新添加回去
                    M.add_items_to_slot(user_id, {
                        item_id = item_list[i].item_id,
                        count = item_list[i].count
                    }, source)
                end
            end
            return false, err
        end
    end
    
    return true
end

-- 获取物品最大堆叠数
local function get_max_stack(item_id)
    local config = table_service.get_item_config(item_id)   
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

-- 【核心功能】处理物品合成逻辑（不涉及背包）
function M.process_compose(target_id, material_items)
    -- 1. 获取合成配置
    local compose_config = table_service.get_compose_config(target_id)
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
    local decompose_config = table_service.get_decompose_config(item.item_id)
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
    
    -- 调用consume_items函数处理单个物品消耗
    local ok, result = M.consume_items(user_id, {
        {
            item_id = item_id,
            count = count
        }
    }, source)
    
    return ok, result
end

-- 消耗物品（单记录操作版本）
function M.consume_items(user_id, items, source)
    if not user_id or not items then
        return false, "invalid params"
    end
    
    -- 设置默认来源
    source = source or enum.ChangeSource.SOURCE_CONSUME
    
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
        local total_before = 0 -- 记录总的原始数量
        
        -- 首先计算总的原始数量
        for _, item in ipairs(user_items) do
            if item.item_id == item_id then
                total_before = total_before + item.count
            end
        end
        
        -- 遍历用户物品列表，扣除物品
        for _, item in ipairs(user_items) do
            if item.item_id == item_id and remain_count > 0 then
                local before_count = item.count
                local consume_count = math.min(remain_count, item.count)
                
                -- 记录这个物品被消耗的数量
                table.insert(consumed_items, {
                    item_id = item_id,
                    count = consume_count
                })
                
                remain_count = remain_count - consume_count
                item.count = item.count - consume_count
                
                -- 使用单记录操作更新物品
                if item.count <= 0 then
                    -- 如果物品数量为0，从数据库中删除记录
                    local bag_type = item.bag_type
                    local slot_index = item.slot_index
                    
                    -- 删除物品记录
                    local delete_ok = item_dao.delete_single_item(item.id, user_id)
                    if not delete_ok then
                        logger.error("Failed to delete item - user_id: %d, item_id: %d, id: %s",
                            user_id, item_id, tostring(item.id))
                        return false, "db error - delete failed"
                    end
                    
                    -- 更新格子状态为空
                    if bag_type and slot_index then
                        bag_dao.update_slot_state(user_id, bag_type, slot_index, enum.SlotState.SLOT_STATE_EMPTY)
                    end
                else
                    -- 如果物品还有剩余，更新单条记录
                    local ok = item_dao.update_single_item(item)
                    if not ok then
                        logger.error("Failed to update item - user_id: %d, item_id: %d, id: %s",
                            user_id, item_id, tostring(item.id))
                        return false, "db error - update failed"
                    end
                end
                
                -- 记录物品变化
                item_dao.log_change(user_id, item_id, consume_count,
                    enum.ChangeType.CHANGE_TYPE_REDUCE, source,
                    before_count, item.count)
                
                -- 如果已经消耗完需要的数量，跳出循环
                if remain_count <= 0 then
                    break
                end
            end
        end
        
        -- 触发物品消耗事件
        local event = init.get_service("event")
        skynet.send(event, "lua", "trigger_event", "on_item_consumed", {
            user_id = user_id,
            item_id = item_id,
            count = need_count,
            remain_count = total_before - need_count,
            source = source
        })
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

return M 