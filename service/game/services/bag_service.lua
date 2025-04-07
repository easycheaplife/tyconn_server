local skynet = require "skynet"
local logger = require "logger"
local bag_dao = require "dao.bag_dao"
local item_dao = require "dao.item_dao"
local bag_model = require "models.bag_model"
local item_model = require "models.item_model"
local config_service = require "services.config_service"
local item_service = require "services.item_service"
local snowflake = require "utils.snowflake"
local user_service = require "services.user_service"
local enum = require "enum"
local utils = require "utils"
local table_service = require "services.table_service"

local M = {}

-- 背包初始化配置
local BAG_CONFIG = {
    [enum.BagType.BAG_TYPE_MAIN] = {
        init_size = 20,    -- 初始格子数
        max_size = 100,    -- 最大格子数
        unlock_level = 1   -- 解锁等级
    }
}

-- 检查物品是否可堆叠
local function can_stack(item_id)
    local config = table_service.get_item_config(item_id)
    if not config then
        return false
    end
    return config.max_stack and config.max_stack > 1
end

-- 获取物品堆叠上限
local function get_stack_limit(item_id)
    local config = table_service.get_item_config(item_id)
    if not config or not config.max_stack then
        return 1
    end
    return config.max_stack
end

-- 初始化用户背包系统
function M.init_user_bags(user_id)
    -- 1. 检查是否已初始化
    local bags = bag_dao.get_user_bags(user_id)
    if bags and #bags > 0 then
        logger.debug("User %d bags already initialized", user_id)
        return true
    end
    
    -- 2. 开始初始化
    logger.info("Initializing bags for user %d", user_id)
    for bag_type, config in pairs(BAG_CONFIG) do
        -- 检查等级限制
        local user_level = user_service.get_user_level(user_id)
        logger.info("User %d level %d", user_id, user_level)
        if user_level >= config.unlock_level then
            -- 创建背包
            local bag = bag_dao.create_bag(user_id, bag_type, config.init_size)
            if not bag then
                logger.error("Failed to create bag type %d for user %d", bag_type, user_id)
                return false
            end
            logger.debug("Created bag type %d with size %d for user %d", 
                bag_type, config.init_size, user_id)
        else
            logger.debug("User %d level %d not meet requirement %d for bag type %d", 
                user_id, user_level, config.unlock_level, bag_type)
        end
    end
    
    logger.info("Successfully initialized bags for user %d", user_id)
    return true
end

-- 检查格子状态是否有效
local function check_slot_state(user_id, bag_type, slot_index)
    -- 1. 获取背包格子
    local slots = bag_dao.get_bag_slots(user_id, bag_type)
    if not slots then
        return false, "获取格子失败"
    end
    
    -- 2. 检查格子索引
    local slot = nil
    for _, s in ipairs(slots) do
        if s.slot_index == slot_index then
            slot = s
            break
        end
    end
    
    if not slot then
        return false, "slot not found"
    end
    
    -- 3. 检查格子状态
    if slot.state == enum.SlotState.SLOT_STATE_LOCKED then
        return false, "slot is locked"
    end
    
    return true
end

-- 检查物品移动是否合法
local function check_move_valid(user_id, from_bag, from_slot, to_bag, to_slot)
    -- 1. 检查源格子状态
    local ok, err = check_slot_state(user_id, from_bag, from_slot)
    if not ok then
        return false, "source slot: " .. err
    end
    
    -- 2. 检查目标格子状态
    ok, err = check_slot_state(user_id, to_bag, to_slot)
    if not ok then
        return false, "target slot: " .. err
    end
    
    -- 3. 检查背包类型
    if to_bag == enum.BagType.BAG_TYPE_EQUIP then
        -- 移动到装备栏需要特殊检查
        return equip_service.check_can_equip(user_id, from_bag, from_slot, to_slot)
    end
    
    return true
end

-- 查找背包中的空格子
function M.find_empty_slot(user_id, bag_type, items)
    -- 获取物品列表（如果未提供）
    local bag_items = items
    if not bag_items then
        bag_items = item_dao.get_user_items(user_id)
        if not bag_items then
            return nil, "get items failed"
        end
    end
    
    -- 找出最小的未使用的格子索引
    local used_slots = {}
    for _, item in ipairs(bag_items) do
        if item.bag_type == bag_type then
            used_slots[item.slot_index] = true
        end
    end
    
    for i = 0, 99 do  -- 假设背包最大100格
        if not used_slots[i] then
            return i
        end
    end
    
    return nil, "bag is full"
end

-- 物品合成函数（对外API，调用item_service）
function M.compose_item(user_id, target_id)
    -- 1. 验证参数
    if not user_id or not target_id then
        logger.error("Invalid params for compose_item: user_id=%s, target_id=%s", 
            tostring(user_id), tostring(target_id))
        return false, "invalid params"
    end
    
    -- 2. 获取物品
    logger.debug("Fetching items for user: %s", tostring(user_id))
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 3. 获取合成配置
    logger.debug("Getting compose config for target_id: %s", tostring(target_id))
    local compose_config = table_service.get_compose_config(target_id)
    if not compose_config then
        logger.error("Compose config not found for target_id: %s", tostring(target_id))
        return false, "compose config not found"
    end
    
    -- 记录配置信息
    logger.debug("Compose config: target_id=%s, material_id=%s, material_count=%s",
        tostring(target_id),
        tostring(compose_config.materials[1].item_id),
        tostring(compose_config.materials[1].count))
    
    -- 4. 自动查找所需材料
    local material_items = {}
    -- 查找指定碎片ID的物品
    local found_item = nil
    for _, item in ipairs(items) do
        if item.item_id == compose_config.materials[1].item_id and 
           item.count >= compose_config.materials[1].count then
            found_item = item
            break
        end
    end
    
    if not found_item then
        logger.error("Not enough shards for item_id: %s, required: %s", 
            tostring(compose_config.materials[1].item_id),
            tostring(compose_config.materials[1].count))
        return false, "not enough shards"
    end
    
    table.insert(material_items, found_item)
    
    -- 5. 调用item_service处理合成逻辑
    local ok, result, new_item_data = item_service.process_compose(target_id, material_items)
    if not ok then
        return false, result
    end
    
    -- 6. 使用consume_items消耗材料物品 (consume_items内部会记录物品变更)
    -- 只消耗实际需要的材料数量
    local consume_ok, consume_result = item_service.consume_items(user_id, {
        {
            item_id = compose_config.materials[1].item_id,
            count = compose_config.materials[1].count
        }
    }, enum.ChangeSource.SOURCE_COMPOSE)
    
    if not consume_ok then
        logger.error("Failed to consume materials - user_id: %d, material_id: %d, count: %d", 
            user_id, compose_config.materials[1].item_id, compose_config.materials[1].count)
        return false, "consume materials failed"
    end
    
    local created_item = nil
    
    -- 7. 如果合成成功，添加新物品到背包（使用add_items_to_slot）
    if result == enum.ComposeResult.SUCCESS and new_item_data then
        -- 使用add_items_to_slot添加新物品
        local add_ok, err, added_items = item_service.add_items_to_slot(
            user_id,
            {
                item_id = new_item_data.item_id,
                count = new_item_data.count
            },
            enum.ChangeSource.SOURCE_COMPOSE
        )
        
        if not add_ok then
            logger.error("Failed to add composed item: %s", err)
            return false, "add item failed"
        end
        
        -- 找到新添加的物品
        if added_items and #added_items > 0 then
            created_item = added_items[1]
        end
    end
    
    -- 8. 返回合成结果
    if created_item then
        -- 确保返回的物品信息格式符合 proto 定义
        local new_item_info = {
            item_id = created_item.item_id,
            count = created_item.count,
            slot = created_item.slot_index,
            bag_type = created_item.bag_type
        }
        
        -- 获取最新的物品列表以构造剩余材料信息
        local updated_items = item_dao.get_user_items(user_id)
        
        -- 构造剩余材料信息
        local remain_items_info = {}
        for _, item in ipairs(updated_items) do
            if item.item_id == compose_config.materials[1].item_id then
                table.insert(remain_items_info, {
                    item_id = item.item_id,
                    count = item.count,
                    slot = item.slot_index,
                    bag_type = item.bag_type
                })
            end
        end
        
        logger.info("Item compose result - success:%s, new_item:%s, remain_items:%s",
            tostring(ok), utils.table_to_string(new_item_info), utils.table_to_string(remain_items_info))
        
        return true, enum.ComposeResult.SUCCESS, new_item_info, remain_items_info
    end
    
    return false, "compose failed"
end

-- 物品分解函数（对外API，调用item_service）
function M.decompose_item(user_id, target_id)
    -- 1. 验证参数
    if not user_id or not target_id then
        return false, "invalid params"
    end
    
    -- 2. 获取物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 3. 找到要分解的物品
    local decompose_item = nil
    for _, item in ipairs(items) do
        if item.item_id == target_id then
            decompose_item = item
            break
        end
    end
    
    if not decompose_item then
        return false, "item not found"
    end
    
    -- 4. 调用item_service处理分解逻辑
    local ok, err, result_items_data = item_service.process_decompose({decompose_item})
    if not ok then
        return false, err
    end
    
    -- 5. 消耗被分解的物品 (consume_items内部会记录物品变更)
    local consume_ok, consume_err = item_service.consume_items(user_id, {
        {
            item_id = target_id,
            count = decompose_item.count
        }
    }, enum.ChangeSource.SOURCE_DECOMPOSE)
    
    if not consume_ok then
        logger.error("Failed to consume item for decompose - user_id: %d, item_id: %d", 
            user_id, target_id)
        return false, "consume item failed"
    end
    
    -- 6. 添加分解结果物品
    local result_items = {}
    if result_items_data and #result_items_data > 0 then
        -- 构造要添加的物品列表
        local items_to_add = {}
        for _, result_data in ipairs(result_items_data) do
            table.insert(items_to_add, {
                item_id = result_data.item_id,
                count = result_data.count
            })
        end
        
        -- 使用add_items_to_slot添加分解得到的物品
        for _, item_to_add in ipairs(items_to_add) do
            local add_ok, add_err, added_items = item_service.add_items_to_slot(
                user_id, 
                item_to_add, 
                enum.ChangeSource.SOURCE_DECOMPOSE
            )
            
            if not add_ok then
                logger.error("Failed to add decomposed item - user_id: %d, item_id: %d, count: %d, error: %s",
                    user_id, item_to_add.item_id, item_to_add.count, add_err)
            else
                -- 将添加成功的物品加入结果列表
                for _, added_item in ipairs(added_items or {}) do
                    table.insert(result_items, added_item)
                end
            end
        end
    end
    
    -- 如果没有成功添加任何分解结果物品，但分解过程本身成功了
    if #result_items == 0 and #result_items_data > 0 then
        logger.warn("Decompose succeeded but no result items were added - user_id: %d, target_id: %d",
            user_id, target_id)
    end
    
    -- 返回成功与分解结果物品
    return true, nil, result_items
end

-- 移动物品
function M.move_item(user_id, src_bag_type, src_slot, dst_bag_type, dst_slot, count)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 2. 查找源物品和目标物品
    local src_item = nil
    local dst_item = nil
    
    for _, item in ipairs(items) do
        if item.bag_type == src_bag_type and item.slot_index == src_slot then
            src_item = item
        elseif item.bag_type == dst_bag_type and item.slot_index == dst_slot then
            dst_item = item
        end
    end
    
    -- 3. 检查源物品是否存在
    if not src_item then
        return false, "source slot is empty"
    end
    
    -- 跟踪变化的物品
    local changed_items = {}
    
    -- 4. 处理部分移动
    local move_count = count or src_item.count
    if move_count <= 0 or move_count > src_item.count then
        move_count = src_item.count
    end
    
    -- 5. 处理移动逻辑
    if dst_item then
        -- 如果目标格子有物品
        if src_item.item_id == dst_item.item_id and 
           table_service.get_item_config(src_item.item_id).max_stack > dst_item.count then
            -- 相同物品且可以堆叠，执行堆叠
            local stack_limit = table_service.get_item_config(src_item.item_id).max_stack
            local stack_count = math.min(move_count, stack_limit - dst_item.count)
            
            -- 堆叠到目标物品
            dst_item.count = dst_item.count + stack_count
            src_item.count = src_item.count - stack_count
            
            -- 记录变化
            table.insert(changed_items, dst_item)
            
            -- 如果源物品堆叠完，清空该格子
            if src_item.count <= 0 then
                -- 从列表中移除
                for i, item in ipairs(items) do
                    if item == src_item then
                        table.remove(items, i)
                        break
                    end
                end
                src_item = nil
            else
                -- 源物品也发生变化
                table.insert(changed_items, src_item)
            end
            
            -- 需要添加:
            item_dao.log_change(user_id, dst_item.item_id, stack_count,
                enum.ChangeType.CHANGE_TYPE_ADD, enum.ChangeSource.SOURCE_MOVE,
                dst_item.count - stack_count, dst_item.count)
            item_dao.log_change(user_id, src_item.item_id, stack_count,
                enum.ChangeType.CHANGE_TYPE_REDUCE, enum.ChangeSource.SOURCE_MOVE,
                src_item.count + stack_count, src_item.count)
        else
            -- 不能堆叠，交换位置
            if move_count < src_item.count and count > 0 then
                -- 部分移动时目标格子必须为空
                return false, "部分移动时目标格子必须为空"
            end
            
            src_item.bag_type, dst_item.bag_type = dst_item.bag_type, src_item.bag_type
            src_item.slot_index, dst_item.slot_index = dst_item.slot_index, src_item.slot_index
            
            -- 记录变化
            table.insert(changed_items, src_item)
            table.insert(changed_items, dst_item)
        end
    else
        -- 目标格子为空
        if move_count < src_item.count and count > 0 then
            -- 部分移动到空格子，创建新物品
            local new_item = item_model.new({
                id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
                user_id = user_id,
                item_id = src_item.item_id,
                count = move_count,
                bag_type = dst_bag_type,
                slot_index = dst_slot
            })
            
            -- 更新源物品
            src_item.count = src_item.count - move_count
            
            -- 添加新物品
            table.insert(items, new_item)
            
            -- 记录变化
            table.insert(changed_items, src_item)
            table.insert(changed_items, new_item)
        else
            -- 全部移动到空格子
            src_item.bag_type = dst_bag_type
            src_item.slot_index = dst_slot
            
            -- 记录变化
            table.insert(changed_items, src_item)
        end
    end
    
    -- 6. 保存更新（只更新变化的记录）
    for _, item in ipairs(changed_items) do
        if item.count <= 0 then
            -- 如果物品数量为0，删除记录
            local ok = item_dao.delete_single_item(item.id, user_id)
            if not ok then
                logger.error("Failed to delete item - user_id: %d, item_id: %d, id: %s",
                    user_id, item.item_id, tostring(item.id))
                return false, "delete item failed"
            end
        else
            -- 更新物品记录
            local ok = item_dao.update_single_item(item)
            if not ok then
                logger.error("Failed to update item - user_id: %d, item_id: %d, id: %s",
                    user_id, item.item_id, tostring(item.id))
                return false, "update item failed"
            end
        end
    end
    
    logger.info("Moving item - user:%d, from_bag:%d, from_slot:%d, to_bag:%d, to_slot:%d, count:%d",
        user_id, src_bag_type, src_slot, dst_bag_type, dst_slot, count or 0)
    logger.info("Item move result - changed_items:%s", utils.table_to_string(changed_items))
    
    return true, nil, changed_items
end

-- 整理背包
function M.sort_bag(user_id, bag_type)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 2. 过滤指定背包的物品
    local bag_items = {}
    for _, item in ipairs(items) do
        if item.bag_type == bag_type then
            table.insert(bag_items, item)
        end
    end
    
    -- 3. 按规则排序
    table.sort(bag_items, function(a, b)
        -- 按物品类型、品质、等级排序
        local config_a = table_service.get_item_config(a.item_id)
        local config_b = table_service.get_item_config(b.item_id)
        
        if not config_a or not config_b then
            return a.item_id < b.item_id
        end
        
        if config_a.type ~= config_b.type then
            return config_a.type < config_b.type
        end
        
        if config_a.quality ~= config_b.quality then
            return config_a.quality > config_b.quality  -- 品质从高到低
        end
        
        if a.item_id ~= b.item_id then
            return a.item_id < b.item_id
        end
        
        -- 相同物品按数量从多到少
        return a.count > b.count
    end)
    
    -- 4. 更新物品位置
    for i, item in ipairs(bag_items) do
        item.slot_index = i - 1  -- 从0开始的索引
    end
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    return true, nil, bag_items
end

-- 整理所有背包
function M.sort_all_bags(user_id, rule)
    -- 1. 检查用户ID
    if not user_id then
        return false, "invalid user id"
    end
    
    -- 2. 整理各类型背包
    local bag_types = {
        enum.BagType.BAG_TYPE_MAIN,
        enum.BagType.BAG_TYPE_STORAGE
    }
    
    for _, bag_type in ipairs(bag_types) do
        local ok, err = M.sort_bag(user_id, bag_type, rule)
        if not ok then
            logger.error("Failed to sort bag %d for user %d: %s", 
                bag_type, user_id, err)
        end
    end
    
    -- 3. 尝试堆叠
    for _, bag_type in ipairs(bag_types) do
        local ok, need_update = M.quick_stack(user_id, bag_type)
        if ok and need_update then
            -- 如果有堆叠，重新排序
            M.sort_bag(user_id, bag_type, rule)
        end
    end
    
    return true
end

-- 获取空格子
function M.find_empty_slots(user_id, bag_type, count)
    -- 1. 获取背包格子
    local slots = bag_dao.get_bag_slots(user_id, bag_type)
    if not slots then
        return nil, "get slots failed"
    end
    
    -- 2. 查找空格子
    local empty_slots = {}
    for _, slot in ipairs(slots) do
        if slot.state == enum.SlotState.SLOT_STATE_EMPTY then
            table.insert(empty_slots, slot)
            if #empty_slots >= count then
                break
            end
        end
    end
    
    if #empty_slots < count then
        return nil, "not enough empty slots"
    end
    
    return empty_slots
end

-- 检查背包容量
function M.check_bag_capacity(user_id, bag_type, need_count)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 2. 统计已使用格子
    local used_slots = {}
    for _, item in ipairs(items) do
        if item.bag_type == bag_type then
            used_slots[item.slot_index] = true
        end
    end
    
    -- 3. 获取背包信息
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        return false, "get bag failed"
    end
    
    -- 4. 计算剩余格子数
    local empty_count = bag.size - table.size(used_slots)
    
    return empty_count >= need_count
end

-- 锁定格子
function M.lock_slot(user_id, bag_type, slot_index)
    return bag_dao.update_slot_state(user_id, bag_type, slot_index, enum.SlotState.SLOT_STATE_LOCKED)
end

-- 解锁格子
function M.unlock_slot(user_id, bag_type, slot_index)
    return bag_dao.update_slot_state(user_id, bag_type, slot_index, enum.SlotState.SLOT_STATE_EMPTY)
end

-- 获取背包信息
function M.get_bag_info(user_id, bag_type)
    -- 获取背包数据
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        return nil, "bag not found"
    end
    
    return {
        size = bag.size,
        bag_type = bag_type
    }
end

-- 获取背包最大容量
function M.get_max_bag_size(bag_type)
    local config = BAG_CONFIG[bag_type]
    if not config then
        return nil, "invalid bag type"
    end
    return config.max_size
end

-- 扩展背包
function M.expand_bag(user_id, bag_type, add_size)
    -- 1. 参数验证
    if not user_id or not bag_type then
        return false, nil, "user id or bag type is invalid"
    end

    -- 验证扩展大小
    if not add_size or add_size <= 0 then
        return false, nil, "expand size must be greater than 0"
    end

    -- 2. 获取背包信息
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        return false, nil, "bag not found"
    end

    -- 3. 检查背包配置
    local config = BAG_CONFIG[bag_type]
    if not config then
        return false, nil, "invalid bag type"
    end

    -- 4. 检查是否超过最大容量
    local new_size = bag.size + add_size
    if new_size > config.max_size then
        return false, nil, "exceeds bag max capacity limit"
    end

    -- 5. 更新背包大小
    local ok = bag_dao.update_bag_size(user_id, bag_type, new_size)
    if not ok then
        return false, nil, "failed to update bag size"
    end

    -- 6. 获取最新的物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, nil, "get items failed"
    end

    -- 7. 清除缓存
    bag_dao.clear_cache(user_id)

    return true, new_size, nil, items
end

-- 清空背包
function M.clear_bag(user_id, bag_type)
    -- 验证背包类型
    if not bag_model.is_valid_bag_type(bag_type) then
        return false, "invalid bag type"
    end
    
    -- 获取用户所有物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 筛选出不在指定背包的物品
    local filtered_items = {}
    for _, item in ipairs(items) do
        if item.bag_type ~= bag_type then
            table.insert(filtered_items, item)
        end
    end
    
    -- 保存更新后的物品列表
    local ok = item_dao.update_user_items(user_id, filtered_items)
    if not ok then
        return false, "save item failed"
    end
    
    logger.info("Clearing bag - user:%d, bag_type:%d, original_items:%d, remaining_items:%d",
        user_id, bag_type, #items, #filtered_items)
    logger.info("Clear bag result - success:%s", tostring(ok))
    
    return true, "bag is cleared"
end

-- 获取用户所有背包信息
function M.get_user_bags(user_id)
    if not user_id then
        return nil, "invalid user id"
    end

    -- 获取用户所有背包
    local bags = bag_dao.get_user_all_bags(user_id)
    if not bags then
        logger.error("get_user_bags: get bags failed")
        return nil, "get bags failed"
    end
    -- 获取用户所有物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        items = {}
    end
    -- 构造返回的背包信息列表
    local bag_info_list = {}
    for _, bag in ipairs(bags) do
        -- 获取该背包中的物品
        local bag_items = {}
        for _, item in ipairs(items) do
            if tonumber(item.bag_type) == tonumber(bag.bag_type) then
                -- 确保所有字段都是数值类型
                local item_info = {
                    item_id = tonumber(item.item_id),
                    count = tonumber(item.count),
                    slot = tonumber(item.slot_index or 0)  -- 确保有默认值
                }
                table.insert(bag_items, item_info)
            end
        end

        -- 构造背包信息
        local bag_info = {
            bag_type = tonumber(bag.bag_type),
            size = tonumber(bag.size),
            items = bag_items
        }
        
        table.insert(bag_info_list, bag_info)
    end
    return bag_info_list
end

-- 添加多个物品到背包
function M.add_items(user_id, items, source)
    if not user_id then
        logger.error("Invalid parameters for add_items: user_id is nil")
        return false, nil
    end
    
    -- 支持单个物品对象或物品对象数组
    local items_array = {}
    if type(items) == "table" then
        if items.item_id and type(items.item_id) ~= "table" then
            -- 单个物品对象
            table.insert(items_array, {
                item_id = items.item_id,
                count = items.count or 1
            })
        elseif items.item_id and type(items.item_id) == "table" then
            -- 处理特殊的嵌套结构 {item_id = {[1] = {item_id=xx, count=xx}}}
            for _, item in pairs(items.item_id) do
                if type(item) == "table" and item.item_id then
                    table.insert(items_array, {
                        item_id = item.item_id,
                        count = item.count or 1
                    })
                end
            end
        elseif items[1] and type(items[1]) == "table" then
            if items[1].item_id then
                -- 物品对象数组
                items_array = items
            else
                -- 处理嵌套的items结构
                for _, item in pairs(items[1]) do
                    if type(item) == "table" and item.item_id then
                        table.insert(items_array, {
                            item_id = item.item_id,
                            count = item.count or 1
                        })
                    end
                end
            end
        end
    end
    
    if #items_array == 0 then
        logger.error("No valid items to add, input structure: %s", utils.table_to_string(items))
        return false, nil
    end
    
    -- 确保日志输出的是处理后的标准格式
    logger.debug("Adding items to bag (processed): user_id=%d, items=%s", 
        user_id, utils.table_to_string(items_array))
    
    -- 调用item_service的add_items_to_slot函数
    local ok, err, added_items = item_service.add_items_to_slot(
        user_id,
        items_array,
        source or enum.ChangeSource.SOURCE_SYSTEM
    )
    
    if not ok then
        logger.error("Failed to add items to bag: user_id=%d, error: %s", 
            user_id, err or "unknown error")
        return false, nil
    end
    
    -- 构建完整的BagInfo结构
    local bags = {}
    for _, bag_change in ipairs(added_items) do
        if bag_change.bag_type then
            -- 查找或创建对应背包类型的BagInfo
            local bag_info = nil
            for _, bag in ipairs(bags) do
                if bag.bag_type == bag_change.bag_type then
                    bag_info = bag
                    break
                end
            end
            
            if not bag_info then
                bag_info = {
                    bag_type = bag_change.bag_type,
                    size = bag_change.size or 0,  -- 背包大小
                    items = {}
                }
                table.insert(bags, bag_info)
            end
            
            -- 添加物品信息
            if bag_change.item_id and bag_change.count then
                table.insert(bag_info.items, {
                    item_id = bag_change.item_id,
                    count = bag_change.count
                })
            end
        end
    end
    
    logger.info("Successfully added items to bag: user_id=%d, items=%s", 
        user_id, utils.table_to_string(items_array))
    return true, bags
end

function M.add_item(user_id, item_id, count, source)
    return M.add_items(user_id, {
        item_id = item_id,
        count = count
    }, source)
end

-- 使用物品
function M.use_item(user_id, item_id, count)
    -- 1. 参数验证
    if not user_id or not item_id or not count or count <= 0 then
        logger.error("Invalid parameters for use_item: user_id=%s, item_id=%s, count=%s", 
            tostring(user_id), tostring(item_id), tostring(count))
        return false, "invalid params", {}
    end
    
    logger.debug("Using item: user_id=%d, item_id=%d, count=%d", user_id, item_id, count)
    
    -- 2. 调用item_service的use_item函数
    local ok, err, result = item_service.use_item(user_id, item_id, count)
    
    if not ok then
        logger.error("Failed to use item: user_id=%d, item_id=%d, count=%d, error: %s", 
            user_id, item_id, count, err or "unknown error")
        return false, err, {}
    end
    
    logger.info("Successfully used item: user_id=%d, item_id=%d, count=%d", 
        user_id, item_id, count)
    
    return true, nil, result
end

-- 消耗物品
function M.consume_item(user_id, item_id, count, source)
    -- 验证基本参数
    if not user_id or not item_id or not count or count <= 0 then
        logger.error("Invalid parameters for consume_item: user_id=%s, item_id=%s, count=%s", 
            tostring(user_id), tostring(item_id), tostring(count))
        return false, "invalid params"
    end
    
    logger.debug("Consuming item: user_id=%d, item_id=%d, count=%d", user_id, item_id, count)
    
    -- 构造items参数调用item_service的consume_items函数
    local ok, consumed_items = item_service.consume_items(user_id, {
        {
            item_id = item_id,
            count = count
        }
    }, source)
    
    if not ok then
        logger.error("Failed to consume item: user_id=%d, item_id=%d, count=%d", 
            user_id, item_id, count)
        return false, consumed_items
    end
    
    logger.info("Successfully consumed item: user_id=%d, item_id=%d, count=%d", 
        user_id, item_id, count)
    
    return true, consumed_items
end

-- 获取用户物品列表
function M.get_user_items(user_id)
    -- 参数验证
    if not user_id then
        logger.error("Invalid parameter for get_user_items: user_id is nil")
        return nil, "invalid user id"
    end
    
    logger.debug("Getting items for user: %d", user_id)
    
    -- 调用item_service获取物品列表
    local items = item_service.get_user_items(user_id)
    
    return items
end

-- 获取物品数量
function M.get_item_count(user_id, item_id)
    -- 参数验证
    if not user_id or not item_id then
        logger.error("Invalid parameters for get_item_count: user_id=%s, item_id=%s", 
            tostring(user_id), tostring(item_id))
        return 0
    end
    
    logger.debug("Getting item count: user_id=%d, item_id=%d", user_id, item_id)
    
    -- 调用item_service获取物品数量
    local count = item_service.get_item_count(user_id, item_id)
    
    logger.info("Item count: user_id=%d, item_id=%d, count=%d", user_id, item_id, count)
    
    return count
end

-- 初始化用户物品
function M.init_user_items(user_id)
    -- 参数验证
    if not user_id then
        logger.error("Invalid parameter for init_user_items: user_id is nil")
        return false, "invalid user id"
    end
    
    logger.debug("Initializing items for user: %d", user_id)
    
    -- 调用item_service初始化用户物品
    local ok, err = item_service.init_user_items(user_id)
    
    if not ok then
        logger.error("Failed to initialize items for user: %d, error: %s", 
            user_id, err or "unknown error")
        return false, err
    end
    
    logger.info("Successfully initialized items for user: %d", user_id)
    
    return true, nil
end

-- 批量移除物品
function M.batch_remove_items(user_id, item_list, source)
    -- 参数验证
    if not user_id or not item_list then
        logger.error("Invalid parameters for batch_remove_items: user_id=%s", tostring(user_id))
        return false, "invalid params"
    end
    
    logger.debug("Removing items: user_id=%d", user_id)
    
    -- 调用item_service批量移除物品
    local ok, err = item_service.batch_remove_items(user_id, item_list, source)
    
    if not ok then
        logger.error("Failed to remove items: user_id=%d", user_id)
        return false, err
    end
    
    logger.info("Successfully removed items: user_id=%d", user_id)
    
    return true, nil
end

return M