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

local M = {}

-- 背包初始化配置
local BAG_CONFIG = {
    [bag_model.BAG_TYPE.MAIN] = {
        init_size = 20,    -- 初始格子数
        max_size = 100,    -- 最大格子数
        unlock_level = 1   -- 解锁等级
    },
    [bag_model.BAG_TYPE.STORAGE] = {
        init_size = 50,
        max_size = 200,
        unlock_level = 10
    },
    [bag_model.BAG_TYPE.EQUIP] = {
        init_size = 8,
        max_size = 8,
        unlock_level = 1
    }
}

-- 装备槽位定义
local EQUIP_SLOTS = {
    WEAPON = 1,     -- 武器
    ARMOR = 2,      -- 护甲
    HELMET = 3,     -- 头盔
    NECKLACE = 4,   -- 项链
    RING = 5,       -- 戒指
    BOOTS = 6       -- 靴子
}

-- 检查物品是否可堆叠
local function can_stack(item_id)
    local config = config_service.get_item_config(item_id)
    if not config then
        return false
    end
    return config.max_stack and config.max_stack > 1
end

-- 获取物品堆叠上限
local function get_stack_limit(item_id)
    local config = config_service.get_item_config(item_id)
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
        return true
    end
    
    -- 2. 开始初始化
    for bag_type, config in pairs(BAG_CONFIG) do
        -- 检查等级限制
        local user_level = user_service.get_user_level(user_id)
        if user_level >= config.unlock_level then
            -- 创建背包
            local bag = bag_dao.create_bag(user_id, bag_type, config.init_size)
            if not bag then
                logger.error("Failed to create bag type %d for user %d", bag_type, user_id)
                return false
            end
        end
    end
    
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
        return false, "格子不存在"
    end
    
    -- 3. 检查格子状态
    if slot.state == bag_model.SLOT_STATE.LOCKED then
        return false, "格子已锁定"
    end
    
    return true
end

-- 检查物品移动是否合法
local function check_move_valid(user_id, from_bag, from_slot, to_bag, to_slot)
    -- 1. 检查源格子状态
    local ok, err = check_slot_state(user_id, from_bag, from_slot)
    if not ok then
        return false, "源格子: " .. err
    end
    
    -- 2. 检查目标格子状态
    ok, err = check_slot_state(user_id, to_bag, to_slot)
    if not ok then
        return false, "目标格子: " .. err
    end
    
    -- 3. 检查背包类型
    if to_bag == bag_model.BAG_TYPE.EQUIP then
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
            return nil, "获取物品失败"
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
    
    return nil, "背包已满"
end

-- 向背包中添加物品
function M.add_item_to_bag(user_id, item_data, bag_type, slot_index)
    -- 1. 获取当前物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 处理背包类型和格子位置
    local target_bag_type = bag_type or bag_model.BAG_TYPE.MAIN
    local target_slot = slot_index
    
    -- 如果未指定格子位置，找一个空格子
    if not target_slot then
        target_slot = M.find_empty_slot(user_id, target_bag_type, items)
        if not target_slot then
            return false, "背包已满"
        end
    end
    
    -- 3. 创建新物品
    local new_item = item_service.create_item(user_id, item_data.item_id, item_data.count)
    if not new_item then
        return false, "创建物品失败"
    end
    
    -- 设置背包和格子信息
    new_item.bag_type = target_bag_type
    new_item.slot_index = target_slot
    
    -- 4. 添加到物品列表
    table.insert(items, new_item)
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true, new_item
end

-- 物品合成函数（对外API，调用item_service）
function M.compose_item(user_id, target_id, material_slots)
    -- 1. 验证参数
    if not user_id or not target_id or not material_slots then
        return false, "无效的参数"
    end
    
    -- 2. 获取物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 找到材料物品
    local material_items = {}
    for _, slot in ipairs(material_slots) do
        local found = false
        for _, item in ipairs(items) do
            if item.bag_type == bag_model.BAG_TYPE.MAIN and item.slot_index == slot then
                table.insert(material_items, item)
                found = true
                break
            end
        end
        
        if not found then
            return false, "背包格子不存在"
        end
    end
    
    -- 4. 调用item_service处理合成逻辑
    local ok, result, new_item_data, remain_items = item_service.process_compose(target_id, material_items)
    if not ok then
        return false, result
    end
    
    -- 5. 从背包中移除被消耗的材料物品
    for i = #items, 1, -1 do
        local item = items[i]
        -- 检查该物品是否是材料之一
        for _, material in ipairs(material_items) do
            if item.id == material.id then
                -- 完全移除该物品
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 6. 添加剩余材料回背包
    for _, remain_item in ipairs(remain_items or {}) do
        -- 创建新物品
        local new_remain_item = item_model.new({
            id = remain_item.id,  -- 保持相同ID
            user_id = user_id,
            item_id = remain_item.item_id,
            count = remain_item.count,
            bag_type = remain_item.bag_type,
            slot_index = remain_item.slot_index
        })
        table.insert(items, new_remain_item)
    end
    
    -- 7. 如果合成成功，添加新物品到背包
    local created_item = nil
    if result == item_model.COMPOSE_RESULT.SUCCESS and new_item_data then
        -- 找一个空格子
        local empty_slot = M.find_empty_slot(user_id, bag_model.BAG_TYPE.MAIN, items)
        if not empty_slot then
            return false, "背包已满"
        end
        
        -- 创建新物品
        created_item = item_model.new({
            id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = user_id,
            item_id = new_item_data.item_id,
            count = new_item_data.count,
            bag_type = bag_model.BAG_TYPE.MAIN,
            slot_index = empty_slot
        })
        
        -- 添加到物品列表
        table.insert(items, created_item)
    end
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    -- 修改：返回新创建的物品对象作为第三个返回值
    return true, result, created_item
end

-- 物品分解函数（对外API，调用item_service）
function M.decompose_item(user_id, item_slots)
    -- 1. 验证参数
    if not user_id or not item_slots or #item_slots == 0 then
        return false, "无效的参数"
    end
    
    -- 2. 获取物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 找到要分解的物品
    local decompose_items = {}
    for _, slot in ipairs(item_slots) do
        local found = false
        for _, item in ipairs(items) do
            if item.bag_type == bag_model.BAG_TYPE.MAIN and item.slot_index == slot then
                table.insert(decompose_items, item)
                found = true
                break
            end
        end
        if not found then
            return false, "背包格子不存在"
        end
    end
    
    -- 4. 调用item_service处理分解逻辑
    local ok, err, result_items_data = item_service.process_decompose(decompose_items)
    if not ok then
        return false, err
    end
    
    -- 5. 从背包中移除要分解的物品
    for _, decompose_item in ipairs(decompose_items) do
        for i = #items, 1, -1 do
            if items[i].id == decompose_item.id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 6. 为分解结果物品找空格子并添加到物品列表
    local result_item_objects = {}
    for _, result_data in ipairs(result_items_data) do
        -- 寻找空格子
        local empty_slot = M.find_empty_slot(user_id, bag_model.BAG_TYPE.MAIN, items)
        if not empty_slot then
            return false, "背包已满"
        end
        
        -- 创建结果物品
        local new_item = item_model.new({
            id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = user_id,
            item_id = result_data.item_id,
            count = result_data.count,
            bag_type = bag_model.BAG_TYPE.MAIN,
            slot_index = empty_slot
        })
        
        -- 添加到物品列表
        table.insert(items, new_item)
        table.insert(result_item_objects, new_item)
    end
    
    -- 7. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true, nil, result_item_objects
end

-- 移动物品
function M.move_item(user_id, src_bag_type, src_slot, dst_bag_type, dst_slot, count)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
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
        return false, "源格子没有物品"
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
           config_service.get_item_config(src_item.item_id).max_stack > dst_item.count then
            -- 相同物品且可以堆叠，执行堆叠
            local stack_limit = config_service.get_item_config(src_item.item_id).max_stack
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
    
    -- 6. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true, nil, changed_items
end

-- 整理背包
function M.sort_bag(user_id, bag_type)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
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
        local config_a = config_service.get_item_config(a.item_id)
        local config_b = config_service.get_item_config(b.item_id)
        
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
        return false, "保存物品失败"
    end
    
    return true, nil, bag_items
end

-- 整理所有背包
function M.sort_all_bags(user_id, rule)
    -- 1. 检查用户ID
    if not user_id then
        return false, "无效的用户ID"
    end
    
    -- 2. 整理各类型背包
    local bag_types = {
        item_model.BAG_TYPE.MAIN,
        item_model.BAG_TYPE.STORAGE
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

-- 拆分物品
function M.split_item(user_id, from_bag, from_slot, to_bag, to_slot, count)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找源物品
    local from_item = nil
    for _, item in ipairs(items) do
        if item.bag_type == from_bag and item.slot_index == from_slot then
            from_item = item
            break
        end
    end
    
    if not from_item then
        return false, "源格子没有物品"
    end
    
    -- 3. 检查数量
    if count <= 0 or count >= from_item.count then
        return false, "拆分数量无效"
    end
    
    -- 4. 检查目标格子是否为空
    for _, item in ipairs(items) do
        if item.bag_type == to_bag and item.slot_index == to_slot then
            return false, "目标格子已被占用"
        end
    end
    
    -- 5. 创建新物品
    local new_item = item_model.new({
        id = snowflake.next_id(),
        user_id = user_id,
        item_id = from_item.item_id,
        count = count,
        bag_type = to_bag,
        slot_index = to_slot
    })
    
    -- 6. 更新源物品数量
    from_item.count = from_item.count - count
    
    -- 7. 添加新物品
    table.insert(items, new_item)
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true
end

-- 装备物品
function M.equip_item(user_id, from_bag, from_slot, equip_slot)
    -- 1. 检查源背包
    local src_bag = M.get_user_bag(user_id, from_bag)
    local equip_bag = M.get_user_bag(user_id, item_model.BAG_TYPE.EQUIP)
    if not src_bag or not equip_bag then
        return false, "背包不存在"
    end
    
    -- 2. 检查源格子
    if not src_bag.slots[from_slot] then
        return false, "源格子不存在"
    end
    
    local src_item = src_bag.slots[from_slot]
    if src_item.state ~= item_model.SLOT_STATE.OCCUPIED then
        return false, "源格子没有物品"
    end
    
    -- 3. 检查装备槽位
    if not equip_bag.slots[equip_slot] then
        return false, "装备槽位不存在"
    end
    
    -- 4. 检查物品是否可装备
    if not can_equip(src_item.item_id, equip_slot) then
        return false, "物品不可装备到该槽位"
    end
    
    -- 5. 卸下当前装备(如果有)
    local curr_equip = equip_bag.slots[equip_slot]
    if curr_equip.state == item_model.SLOT_STATE.OCCUPIED then
        -- 查找主背包空格子
        local main_bag = M.get_user_bag(user_id, item_model.BAG_TYPE.MAIN)
        local empty_slot = nil
        for i = 1, main_bag.size do
            if main_bag.slots[i].state == item_model.SLOT_STATE.EMPTY then
                empty_slot = i
                break
            end
        end
        
        if not empty_slot then
            return false, "背包已满，无法卸下当前装备"
        end
        
        -- 移动到主背包
        main_bag.slots[empty_slot] = curr_equip
        main_bag.slots[empty_slot].index = empty_slot
        
        -- 保存主背包更新
        local ok = bag_dao.update_user_bag(user_id, item_model.BAG_TYPE.MAIN, main_bag)
        if not ok then
            return false, "更新背包失败"
        end
    end
    
    -- 6. 装备新物品
    equip_bag.slots[equip_slot] = src_item
    equip_bag.slots[equip_slot].index = equip_slot
    
    -- 7. 清空源格子
    src_bag.slots[from_slot] = {
        index = from_slot,
        state = item_model.SLOT_STATE.EMPTY
    }
    
    -- 8. 保存更新
    local ok = bag_dao.update_user_bag(user_id, from_bag, src_bag)
    if not ok then
        return false, "更新源背包失败"
    end
    
    ok = bag_dao.update_user_bag(user_id, item_model.BAG_TYPE.EQUIP, equip_bag)
    if not ok then
        return false, "更新装备栏失败"
    end
    
    -- 9. 重新计算属性
    local property_service = require "services.property_service"
    property_service.recalc_equip_property(user_id)
    
    return true
end

-- 检查背包数据是否有效
local function validate_bag(bag)
    if not bag then
        return false, "背包数据为空"
    end
    
    if not bag.user_id then
        return false, "用户ID为空"
    end
    
    if not bag.bag_type then
        return false, "背包类型为空"
    end
    
    if not bag.slots then
        return false, "格子数据为空"
    end
    
    -- 检查每个格子
    for i, slot in pairs(bag.slots) do
        -- 检查索引
        if slot.index ~= i then
            return false, string.format("格子索引不匹配: %d != %d", slot.index, i)
        end
        
        -- 检查状态
        if slot.state == item_model.SLOT_STATE.OCCUPIED then
            -- 检查物品数据
            if not slot.item_id then
                return false, string.format("格子 %d 物品ID为空", i)
            end
            
            if not slot.count or slot.count <= 0 then
                return false, string.format("格子 %d 物品数量无效", i)
            end
        end
    end
    
    return true
end

-- 修复背包数据
function M.repair_bag(user_id, bag_type)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 获取背包信息
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        return false, "获取背包失败"
    end
    
    -- 3. 检查物品是否有效
    local valid_items = {}
    local invalid_items = {}
    
    for _, item in ipairs(items) do
        if item.bag_type == bag_type then
            -- 检查物品配置是否存在
            local config = config_service.get_item_config(item.item_id)
            if not config then
                table.insert(invalid_items, item)
            -- 检查格子是否超过背包大小
            elseif item.slot_index >= bag.size then
                table.insert(invalid_items, item)
            else
                table.insert(valid_items, item)
            end
        else
            table.insert(valid_items, item)
        end
    end
    
    -- 4. 如果存在无效物品，重新安排格子
    if #invalid_items > 0 then
        for _, item in ipairs(invalid_items) do
            -- 找到空格子
            local empty_slot = M.find_empty_slot(user_id, bag_type, valid_items)
            if empty_slot then
                item.bag_type = bag_type
                item.slot_index = empty_slot
                table.insert(valid_items, item)
            else
                logger.warn("No empty slot for invalid item %d of user %d", 
                    item.id, user_id)
            end
        end
        
        -- 保存修复后的物品列表
        local ok = item_dao.update_user_items(user_id, valid_items)
        if not ok then
            return false, "保存物品失败"
        end
    end
    
    return true
end

-- 修复用户所有背包
function M.repair_all_bags(user_id)
    -- 1. 检查用户是否存在
    local user = user_dao.get_user_by_id(user_id)
    if not user then
        return false, "用户不存在"
    end
    
    -- 2. 修复各类型背包
    for bag_type, _ in pairs(BAG_CONFIG) do
        local ok, err = M.repair_bag(user_id, bag_type)
        if not ok then
            logger.error("Failed to repair bag %d for user %d: %s", 
                bag_type, user_id, err)
        end
    end
    
    return true
end

-- 获取空格子
function M.find_empty_slots(user_id, bag_type, count)
    -- 1. 获取背包格子
    local slots = bag_dao.get_bag_slots(user_id, bag_type)
    if not slots then
        return nil, "获取格子失败"
    end
    
    -- 2. 查找空格子
    local empty_slots = {}
    for _, slot in ipairs(slots) do
        if slot.state == bag_model.SLOT_STATE.EMPTY then
            table.insert(empty_slots, slot)
            if #empty_slots >= count then
                break
            end
        end
    end
    
    if #empty_slots < count then
        return nil, "空格子不足"
    end
    
    return empty_slots
end

-- 检查背包容量
function M.check_bag_capacity(user_id, bag_type, need_count)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
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
        return false, "获取背包失败"
    end
    
    -- 4. 计算剩余格子数
    local empty_count = bag.size - table.size(used_slots)
    
    return empty_count >= need_count
end

-- 锁定格子
function M.lock_slot(user_id, bag_type, slot_index)
    return bag_dao.update_slot_state(user_id, bag_type, slot_index, bag_model.SLOT_STATE.LOCKED)
end

-- 解锁格子
function M.unlock_slot(user_id, bag_type, slot_index)
    return bag_dao.update_slot_state(user_id, bag_type, slot_index, bag_model.SLOT_STATE.EMPTY)
end

-- 获取背包信息
function M.get_bag_info(user_id, bag_type)
    -- 获取背包数据
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        return nil, "背包不存在"
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
        return nil, "无效的背包类型"
    end
    return config.max_size
end

-- 扩展背包
function M.expand_bag(user_id, bag_type, add_size)
    -- 1. 参数验证
    if not user_id or not bag_type then
        return false, nil, "用户ID或背包类型无效"
    end

    -- 验证扩展大小
    if not add_size or add_size <= 0 then
        return false, nil, "扩展大小必须大于0"
    end

    -- 2. 获取背包信息
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        return false, nil, "背包不存在"
    end

    -- 3. 检查背包配置
    local config = BAG_CONFIG[bag_type]
    if not config then
        return false, nil, "无效的背包类型"
    end

    -- 4. 检查是否超过最大容量
    local new_size = bag.size + add_size
    if new_size > config.max_size then
        return false, nil, "超过背包最大容量限制"
    end

    -- 5. 更新背包大小
    local ok = bag_dao.update_bag_size(user_id, bag_type, new_size)
    if not ok then
        return false, nil, "更新背包大小失败"
    end

    -- 6. 获取最新的物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, nil, "获取物品列表失败"
    end

    -- 7. 清除缓存
    bag_dao.clear_cache(user_id)

    return true, new_size, nil, items
end

-- 清空背包
function M.clear_bag(user_id, bag_type)
    -- 验证背包类型
    if not bag_model.is_valid_bag_type(bag_type) then
        return false, "无效的背包类型"
    end
    
    -- 获取用户所有物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
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
        return false, "保存物品失败"
    end
    
    return true, "背包已清空"
end

-- 获取用户所有背包信息
function M.get_user_bags(user_id)
    if not user_id then
        return nil, "无效的用户ID"
    end

    -- 获取用户所有背包
    local bags = bag_dao.get_user_all_bags(user_id)
    if not bags then
        return nil, "获取背包失败"
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
            if item.bag_type == bag.bag_type then
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

return M 