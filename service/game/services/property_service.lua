local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local item_dao = require "dao.item_dao"
local bag_model = require "models.bag_model"
local item_model = require "models.item_model"
local config_service = require "services.config_service"
local enum = require "game.define.enum"

local M = {}

-- 属性类型定义
local PROPERTY_TYPE = {
    HP = 102,
    ATTACK = 103,
    DEFENSE = 104
}

-- 计算类型
local CALC_TYPE = {
    VALUE = 1,    -- 直接值
    PERCENT = 2   -- 万分比
}

-- 属性类型
local PROP_TYPE = {
    ATK = "atk",           -- 攻击力
    DEF = "def",           -- 防御力
    HP = "hp",             -- 生命值
    MP = "mp",             -- 魔法值
    CRIT_RATE = "crit",    -- 暴击率
    CRIT_DMG = "crit_dmg", -- 暴击伤害
    SPEED = "speed",       -- 速度
    DODGE = "dodge"        -- 闪避率
}

-- 计算装备基础属性
local function calc_base_props(equip)
    local props = {}
    local config = config_service.get_item_config(equip.item_id)
    if not config or not config.base_props then
        return props
    end
    
    -- 复制基础属性
    for prop_type, value in pairs(config.base_props) do
        props[prop_type] = value
    end
    
    return props
end

-- 计算强化属性
local function calc_enhance_props(equip)
    local props = {}
    if not equip.enhance_level or equip.enhance_level <= 0 then
        return props
    end
    
    local config = require("config.enhance_config")[equip.enhance_level]
    if not config then
        return props
    end
    
    -- 计算强化加成
    local base_props = calc_base_props(equip)
    for prop_type, base_value in pairs(base_props) do
        props[prop_type] = math.floor(base_value * config.prop_ratio)
    end
    
    return props
end

-- 计算精炼属性
local function calc_refine_props(equip)
    local props = {}
    if not equip.refine_level or equip.refine_level <= 0 then
        return props
    end
    
    local config = require("config.refine_config")[equip.refine_level]
    if not config then
        return props
    end
    
    -- 计算精炼加成
    local base_props = calc_base_props(equip)
    for prop_type, base_value in pairs(base_props) do
        props[prop_type] = math.floor(base_value * config.prop_ratio)
    end
    
    return props
end

-- 计算宝石属性
local function calc_gem_props(equip)
    local props = {}
    if not equip.gem_slots then
        return props
    end
    
    -- 累加所有宝石属性
    for _, slot in pairs(equip.gem_slots) do
        if slot.state == enum.GemSlotState.OCCUPIED then
            local gem_config = config_service.get_item_config(slot.gem_id)
            if gem_config and gem_config.props then
                for prop_type, value in pairs(gem_config.props) do
                    props[prop_type] = (props[prop_type] or 0) + value
                end
            end
        end
    end
    
    return props
end

-- 合并属性
local function merge_props(...)
    local result = {}
    for _, props in ipairs({...}) do
        for prop_type, value in pairs(props) do
            result[prop_type] = (result[prop_type] or 0) + value
        end
    end
    return result
end

-- 计算单件装备的所有属性
local function calc_equip_props(equip)
    -- 计算各部分属性
    local base = calc_base_props(equip)
    local enhance = calc_enhance_props(equip)
    local refine = calc_refine_props(equip)
    local gem = calc_gem_props(equip)
    
    -- 合并所有属性
    return merge_props(base, enhance, refine, gem)
end

-- 重新计算装备属性
function M.recalc_equip_props(user_id)
    -- 1. 获取所有装备
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false
    end
    
    -- 2. 计算总属性
    local total_props = {}
    for _, item in ipairs(items) do
        if item.bag_type == enum.BagType.BAG_TYPE_EQUIP then
            local props = calc_equip_props(item)
            total_props = merge_props(total_props, props)
        end
    end
    
    -- 3. 更新用户属性
    local user_service = require "services.user_service"
    local ok = user_service.update_equip_props(user_id, total_props)
    if not ok then
        return false
    end
    
    -- 4. 触发属性更新事件
    skynet.send(".event", "lua", "trigger_event", "on_property_changed", {
        user_id = user_id,
        props = total_props,
        source = "equip"
    })
    
    return true
end

-- 获取装备评分
function M.get_equip_score(equip)
    -- 1. 获取所有属性
    local props = calc_equip_props(equip)
    
    -- 2. 计算评分
    local score = 0
    local config = require("config.score_config")
    
    for prop_type, value in pairs(props) do
        local weight = config.prop_weight[prop_type] or 1
        score = score + value * weight
    end
    
    -- 3. 品质加成
    local item_config = require("config.item_config")[equip.item_id]
    if item_config and item_config.quality then
        local quality_ratio = config.quality_ratio[item_config.quality] or 1
        score = score * quality_ratio
    end
    
    return math.floor(score)
end

-- 查找属性配置
local function find_property_list(property_id, level)
    logger.info("Finding property list for id: %s, level: %d", property_id, level)
    -- 直接获取对应的属性配置
    local config = config_service.get_property_config(property_id, level)
    if not config then
        logger.error("No property config found for id: %s, level: %d", property_id, level)
        return {}
    end

    local result = {}
    -- 遍历 Property 数组获取具体属性
    for _, prop in pairs(config.property) do
        table.insert(result, {
            prop[1],  -- Property_type (102=HP, 103=攻击, 104=防御)
            prop[2],  -- Calc_type (1=值, 2=万分比)
            prop[3]   -- Value
        })
    end
    logger.info("Found property list: %s", utils.table_to_string(result))
    return result
end

-- 计算单个属性的最终值
local function calculate_property(property_list, property_type)
    local base_value = 0
    local percent = 0
    
    -- 遍历所有属性配置
    for _, prop in ipairs(property_list) do
        local prop_type = prop[1]
        local calc_type = prop[2]
        local value = prop[3]
        -- 找到匹配的属性类型
        if prop_type == property_type then
            if calc_type == CALC_TYPE.VALUE then
                base_value = base_value + value
            elseif calc_type == CALC_TYPE.PERCENT then
                percent = percent + value
            end
        end
    end
    
    -- 计算最终值（基础值 * (1 + 万分比/10000)）
    local result = math.floor(base_value * (1 + percent/10000))
    logger.info("calculate_property result: %d, property_type: %d, base_value: %d, percent: %d", 
        result, property_type, base_value, percent)
    return result
end

-- 获取单位属性
function M.get_unit_property(unit_id, level)
    logger.info("Getting unit property - unit_id: %d, level: %d", unit_id, level)
    
    -- 1. 从unit配置中获取property_id
    local target_unit = config_service.get_unit_config(unit_id)
    if not target_unit then
        logger.error("Unit not found in config: %d", unit_id)
        return nil
    end
    
    logger.info("Found target unit: %s", utils.table_to_string(target_unit))
    local property_id = target_unit.property_id
    if not property_id then
        logger.error("Property_id not found for unit: %d", unit_id)
        return nil
    end

    -- 2. 查找对应的属性配置列表
    local property_list = find_property_list(property_id, level)
    if not property_list or #property_list == 0 then
        logger.error("Property not found for id: %s, level: %d", property_id, level)
        return nil
    end

    -- 3. 计算各个属性的最终值
    local result = {
        hp = calculate_property(property_list, PROPERTY_TYPE.HP),
        attack = calculate_property(property_list, PROPERTY_TYPE.ATTACK),
        defense = calculate_property(property_list, PROPERTY_TYPE.DEFENSE)
    }

    logger.info("Calculated unit property: %s", utils.table_to_string(result))
    return result
end

-- 重新计算装备属性
function M.recalc_equip_property(user_id)
    -- 1. 获取装备栏
    local bag_service = require "services.bag_service"
    local equip_bag = bag_service.get_user_bag(user_id, enum.BagType.BAG_TYPE_EQUIP)
    if not equip_bag then
        return false, "get equip bag failed"
    end
    
    -- 2. 计算总属性
    local total_property = {
        hp = 0,
        attack = 0,
        defense = 0
    }
    
    -- 3. 遍历装备
    for _, slot in pairs(equip_bag.slots) do
        if slot.state == enum.SlotState.SLOT_STATE_OCCUPIED then
            local config = config_service.get_item_config(slot.item_id)
            if config then
                total_property.hp = total_property.hp + (config.hp or 0)
                total_property.attack = total_property.attack + (config.attack or 0)
                total_property.defense = total_property.defense + (config.defense or 0)
            end
        end
    end
    
    -- 4. 更新用户属性
    return user_service.update_equip_property(user_id, total_property)
end

return M 