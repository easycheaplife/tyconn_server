local skynet = require "skynet"
local logger = require "logger"
local bag_dao = require "dao.bag_dao"
local item_dao = require "dao.item_dao"
local bag_model = require "models.bag_model"
local item_model = require "models.item_model"
local config_service = require "services.config_service"
local snowflake = require "utils.snowflake"

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
    local config = require("config.item_config")[item_id]
    if not config then
        return false
    end
    return config.stack_limit and config.stack_limit > 1
end

-- 获取物品堆叠上限
local function get_stack_limit(item_id)
    local config = require("config.item_config")[item_id]
    if not config or not config.stack_limit then
        return 1
    end
    return config.stack_limit
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
                -- 部分移动且目标格子有物品，无法执行
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
        
        if config_a.type ~= config_b.type then
            return config_a.type < config_b.type
        end
        
        if config_a.quality ~= config_b.quality then
            return config_a.quality > config_b.quality
        end
        
        return config_a.id < config_b.id
    end)
    
    -- 4. 重新分配格子
    for i, item in ipairs(bag_items) do
        item.slot_index = i - 1
    end
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true, '整理成功', items
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
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)
    if not bag then
        -- 重新初始化背包
        local config = BAG_CONFIG[bag_type]
        if not config then
            return false, "背包类型无效"
        end
        
        bag = {
            user_id = user_id,
            bag_type = bag_type,
            size = config.init_size,
            slots = {}
        }
        
        -- 初始化格子
        for i = 1, config.init_size do
            bag.slots[i] = {
                index = i,
                state = item_model.SLOT_STATE.EMPTY
            }
        end
    else
        -- 修复格子数据
        for i = 1, bag.size do
            -- 确保格子存在
            if not bag.slots[i] then
                bag.slots[i] = {
                    index = i,
                    state = item_model.SLOT_STATE.EMPTY
                }
            end
            
            -- 修复格子索引
            bag.slots[i].index = i
            
            -- 检查物品数据
            if bag.slots[i].state == item_model.SLOT_STATE.OCCUPIED then
                if not bag.slots[i].item_id or not bag.slots[i].count or bag.slots[i].count <= 0 then
                    -- 无效的物品数据，清空格子
                    bag.slots[i] = {
                        index = i,
                        state = item_model.SLOT_STATE.EMPTY
                    }
                end
            end
        end
    end
    
    -- 2. 保存修复后的数据
    local ok = bag_dao.update_user_bag(user_id, bag_type, bag)
    if not ok then
        return false, "保存背包数据失败"
    end
    
    return true
end

-- 检查并修复所有背包
function M.repair_all_bags(user_id)
    -- 1. 检查用户ID
    if not user_id then
        return false, "无效的用户ID"
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
    -- 1. 获取背包格子
    local slots = bag_dao.get_bag_slots(user_id, bag_type)
    if not slots then
        return false, "获取格子失败"
    end
    
    -- 2. 统计空格子
    local empty_count = 0
    for _, slot in ipairs(slots) do
        if slot.state == bag_model.SLOT_STATE.EMPTY then
            empty_count = empty_count + 1
        end
    end
    
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

-- 物品合成
function M.compose_item(user_id, target_id, material_slots)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 获取合成配置
    local compose_config = config_service.get_compose_config(target_id)
    if not compose_config then
        return false, "物品不可合成"
    end
    
    -- 3. 检查材料槽位是否有效
    if #material_slots ~= #compose_config.materials then
        return false, "材料数量不匹配"
    end
    
    -- 4. 收集材料物品
    local material_items = {}
    local material_map = {}
    
    -- 构建材料ID到需求数量的映射
    for _, material in ipairs(compose_config.materials) do
        material_map[material.item_id] = material.count
    end
    
    -- 验证用户提供的材料
    for _, slot in ipairs(material_slots) do
        local found = false
        for _, item in ipairs(items) do
            if item.slot_index == slot and item.bag_type == bag_model.BAG_TYPE.MAIN then
                if material_map[item.item_id] then
                    -- 验证数量是否足够
                    if item.count < material_map[item.item_id] then
                        return false, "材料数量不足"
                    end
                    material_items[#material_items + 1] = item
                    found = true
                    break
                else
                    return false, "无效的材料"
                end
            end
        end
        if not found then
            return false, "背包格子不存在"
        end
    end
    
    -- 5. 扣除材料
    local remain_items = {}
    for i, item in ipairs(material_items) do
        local required = material_map[item.item_id]
        item.count = item.count - required
        
        if item.count > 0 then
            -- 如果材料有剩余，记录到剩余物品中
            remain_items[#remain_items + 1] = item
        else
            -- 如果材料用完，从物品列表中移除
            for j, it in ipairs(items) do
                if it.id == item.id then
                    table.remove(items, j)
                    break
                end
            end
        end
    end
    
    -- 6. 寻找空格子放置合成物品
    local empty_slot = nil
    for i = 0, 99 do  -- 假设背包最大100格
        local occupied = false
        for _, item in ipairs(items) do
            if item.bag_type == bag_model.BAG_TYPE.MAIN and item.slot_index == i then
                occupied = true
                break
            end
        end
        if not occupied then
            empty_slot = i
            break
        end
    end
    
    if not empty_slot then
        return false, "背包已满"
    end
    
    -- 7. 创建合成物品
    local new_item = item_model.new({
        id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
        user_id = user_id,
        item_id = target_id,
        count = compose_config.result_count or 1,
        bag_type = bag_model.BAG_TYPE.MAIN,
        slot_index = empty_slot
    })
    
    -- 添加到物品列表
    table.insert(items, new_item)
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true, nil, new_item, remain_items
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

-- 物品分解函数
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
    
    -- 4. 检查物品是否可分解
    local result_items = {}
    for _, item in ipairs(decompose_items) do
        -- 获取分解配方
        local decompose_config = config_service.get_decompose_config(item.item_id)
        if not decompose_config then
            return false, "物品不可分解"
        end
        
        -- 收集分解结果
        for _, result in ipairs(decompose_config.results) do
            local found = false
            -- 检查是否已有该物品，尝试堆叠
            for _, res_item in ipairs(result_items) do
                if res_item.item_id == result.item_id then
                    res_item.count = res_item.count + result.count * item.count
                    found = true
                    break
                end
            end
            
            -- 如果没有找到，创建新的结果物品
            if not found then
                table.insert(result_items, {
                    item_id = result.item_id,
                    count = result.count * item.count
                })
            end
        end
    end
    
    -- 5. 从背包中移除要分解的物品
    for _, item in ipairs(decompose_items) do
        for i, it in ipairs(items) do
            if it.id == item.id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 6. 添加分解结果物品到背包
    local result_item_objects = {}
    for _, result in ipairs(result_items) do
        -- 寻找空格子
        local empty_slot = nil
        for i = 0, 99 do  -- 假设背包最大100格
            local occupied = false
            for _, item in ipairs(items) do
                if item.bag_type == bag_model.BAG_TYPE.MAIN and item.slot_index == i then
                    occupied = true
                    break
                end
            end
            if not occupied then
                empty_slot = i
                break
            end
        end
        
        if not empty_slot then
            return false, "背包已满"
        end
        
        -- 创建结果物品
        local new_item = item_model.new({
            id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = user_id,
            item_id = result.item_id,
            count = result.count,
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

return M 