local skynet = require "skynet"
local logger = require "logger"
local bag_dao = require "dao.bag_dao"
local item_dao = require "dao.item_dao"
local bag_model = require "models.bag_model"
local item_model = require "models.item_model"
local property_service = require "services.property_service"

local M = {}

-- 检查物品是否可装备
function M.check_can_equip(user_id, from_bag, from_slot, equip_slot)
    -- 1. 获取物品信息
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找物品
    local item = nil
    for _, it in ipairs(items) do
        if it.bag_type == from_bag and it.slot_index == from_slot then
            item = it
            break
        end
    end
    
    if not item then
        return false, "物品不存在"
    end
    
    -- 3. 检查物品类型
    local config = require("config.item_config")[item.item_id]
    if not config or config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false, "物品不是装备"
    end
    
    -- 4. 检查装备位置
    if config.equip_slot ~= equip_slot then
        return false, "装备位置不匹配"
    end
    
    -- 5. 检查等级限制
    if config.level_required then
        local user_level = user_service.get_user_level(user_id)
        if user_level < config.level_required then
            return false, "等级不足"
        end
    end
    
    return true
end

-- 装备物品
function M.equip_item(user_id, from_bag, from_slot, equip_slot)
    -- 1. 检查是否可装备
    local ok, err = M.check_can_equip(user_id, from_bag, from_slot, equip_slot)
    if not ok then
        return false, err
    end
    
    -- 2. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 查找源物品
    local from_item = nil
    for _, item in ipairs(items) do
        if item.bag_type == from_bag and item.slot_index == from_slot then
            from_item = item
            break
        end
    end
    
    if not from_item then
        return false, "源物品不存在"
    end
    
    -- 4. 查找当前装备
    local curr_equip = nil
    for _, item in ipairs(items) do
        if item.bag_type == bag_model.BAG_TYPE.EQUIP and item.slot_index == equip_slot then
            curr_equip = item
            break
        end
    end
    
    -- 5. 交换位置
    from_item.bag_type = bag_model.BAG_TYPE.EQUIP
    from_item.slot_index = equip_slot
    
    if curr_equip then
        -- 将原装备移到源格子
        curr_equip.bag_type = from_bag
        curr_equip.slot_index = from_slot
    end
    
    -- 6. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    -- 7. 更新属性
    property_service.recalc_equip_props(user_id)
    
    -- 8. 触发装备事件
    skynet.send(".event", "lua", "trigger_event", "on_equip_changed", {
        user_id = user_id,
        equip_id = from_item.id,
        slot = equip_slot,
        action = "equip"
    })
    
    return true
end

-- 卸下装备
function M.unequip_item(user_id, equip_slot, to_bag, to_slot)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.bag_type == bag_model.BAG_TYPE.EQUIP and item.slot_index == equip_slot then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "装备不存在"
    end
    
    -- 3. 检查目标格子
    for _, item in ipairs(items) do
        if item.bag_type == to_bag and item.slot_index == to_slot then
            return false, "目标格子已被占用"
        end
    end
    
    -- 4. 移动装备
    equip.bag_type = to_bag
    equip.slot_index = to_slot
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    -- 6. 更新属性
    property_service.recalc_equip_props(user_id)
    
    -- 7. 触发卸装事件
    skynet.send(".event", "lua", "trigger_event", "on_equip_changed", {
        user_id = user_id,
        equip_id = equip.id,
        slot = equip_slot,
        action = "unequip"
    })
    
    return true
end

-- 移动装备(处理装备栏相关的移动)
function M.move_equipment(user_id, from_bag, from_slot, to_bag, to_slot)
    if from_bag == bag_model.BAG_TYPE.EQUIP then
        -- 从装备栏卸下
        return M.unequip_item(user_id, from_slot, to_bag, to_slot)
    else
        -- 装备到装备栏
        return M.equip_item(user_id, from_bag, from_slot, to_slot)
    end
end

-- 获取装备列表
function M.get_equipments(user_id)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return nil
    end
    
    -- 2. 过滤装备栏物品
    local equipments = {}
    for _, item in ipairs(items) do
        if item.bag_type == bag_model.BAG_TYPE.EQUIP then
            equipments[item.slot_index] = item
        end
    end
    
    return equipments
end

-- 检查装备是否已过期
function M.check_equipment_expired(user_id)
    -- 1. 获取装备列表
    local equipments = M.get_equipments(user_id)
    if not equipments then
        return
    end
    
    -- 2. 检查过期装备
    local now = os.time()
    local need_update = false
    
    for slot, equip in pairs(equipments) do
        if equip.expire_time and equip.expire_time <= now then
            -- 自动卸下过期装备
            local ok = M.unequip_item(user_id, slot, bag_model.BAG_TYPE.MAIN, 0)
            if ok then
                need_update = true
            end
        end
    end
    
    -- 3. 如果有装备变更，重新计算属性
    if need_update then
        property_service.recalc_equip_props(user_id)
    end
end

return M 