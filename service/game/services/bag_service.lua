local skynet = require "skynet"
local logger = require "logger"
local bag_dao = require "dao.bag_dao"
local item_dao = require "dao.item_dao"
local bag_model = require "models.bag_model"
local item_model = require "models.item_model"

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

-- 获取物品配置
local function get_item_config(item_id)
    local config = require("config.item_config")[item_id]
    if not config then
        return nil
    end
    return config
end

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

-- 检查物品是否可装备
local function can_equip(item_id, slot_index)
    local config = get_item_config(item_id)
    if not config then
        return false
    end
    
    -- 检查物品类型
    if config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false
    end
    
    -- 检查装备类型与槽位是否匹配
    return config.equip_type == slot_index
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

-- 移动物品(支持堆叠)
function M.move_item(user_id, from_bag, from_slot, to_bag, to_slot)
    -- 1. 检查移动是否合法
    local ok, err = check_move_valid(user_id, from_bag, from_slot, to_bag, to_slot)
    if not ok then
        return false, err
    end
    
    -- 2. 如果是装备栏操作，转给装备服务处理
    if from_bag == bag_model.BAG_TYPE.EQUIP or to_bag == bag_model.BAG_TYPE.EQUIP then
        local equip_service = require "services.equip_service"
        return equip_service.move_equipment(user_id, from_bag, from_slot, to_bag, to_slot)
    end
    
    -- 3. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 4. 执行移动
    -- 2. 查找源格子物品
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
    
    -- 3. 查找目标格子物品
    local to_item = nil
    for _, item in ipairs(items) do
        if item.bag_type == to_bag and item.slot_index == to_slot then
            to_item = item
            break
        end
    end
    
    -- 4. 处理堆叠
    if to_item and to_item.item_id == from_item.item_id and can_stack(to_item.item_id) then
        local stack_limit = get_stack_limit(to_item.item_id)
        local can_add = stack_limit - to_item.count
        
        if can_add > 0 then
            -- 计算实际堆叠数量
            local add_count = math.min(can_add, from_item.count)
            
            -- 更新数量
            to_item.count = to_item.count + add_count
            from_item.count = from_item.count - add_count
            
            -- 如果源物品数量为0，移除该物品
            if from_item.count <= 0 then
                for i, item in ipairs(items) do
                    if item == from_item then
                        table.remove(items, i)
                        break
                    end
                end
            end
        else
            return false, "目标格子已达到堆叠上限"
        end
    else
        -- 5. 不能堆叠时交换位置
        if to_item then
            -- 两个格子都有物品,交换位置
            from_item.bag_type = to_bag
            from_item.slot_index = to_slot
            to_item.bag_type = from_bag
            to_item.slot_index = from_slot
        else
            -- 目标格子为空,直接移动
            from_item.bag_type = to_bag
            from_item.slot_index = to_slot
        end
    end
    
    -- 6. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true
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
        local config_a = require("config.item_config")[a.item_id]
        local config_b = require("config.item_config")[b.item_id]
        
        if config_a.type ~= config_b.type then
            return config_a.type < config_b.type
        end
        
        if config_a.quality ~= config_b.quality then
            return config_a.quality > config_b.quality
        end
        
        return config_a.level > config_b.level
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

return M 