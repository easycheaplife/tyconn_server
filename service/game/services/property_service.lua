local logger = require "logger"
local config_loader = require "game.config_loader"
local utils = require "utils"

local M = {}

-- 加载配置
local unit_config = config_loader.get_config("Dfw_unit")
local property_config = config_loader.get_config("Dfw_property")

if not unit_config or not property_config then
    logger.error("Failed to load required configs")
end

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

-- 查找属性配置
local function find_property_list(property_id)
    -- 遍历找到对应的 property_id 配置
    for _, config in pairs(property_config) do
        if config.Property_id == property_id then
            local result = {}
            -- 遍历 Property 数组获取具体属性
            for _, prop in pairs(config.Property) do
                table.insert(result, {
                    prop[1],  -- Property_type (102=HP, 103=攻击, 104=防御)
                    prop[2],  -- Calc_type (1=值, 2=万分比)
                    prop[3]   -- Value
                })
            end
            return result
        end
    end
    
    logger.error("No property config found for id: %s", property_id)
    return {}
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
    return math.floor(base_value * (1 + percent/10000))
end

-- 获取单位属性
function M.get_unit_property(unit_id, level)
    -- 1. 从unit配置中获取property_id
    local target_unit
    for _, unit in pairs(unit_config) do
        if unit.Unit_id == unit_id then
            target_unit = unit
            break
        end
    end

    if not target_unit then
        logger.error("Unit not found in config: %d", unit_id)
        return nil
    end
    
    local property_id = target_unit.Property_id
    if not property_id then
        logger.error("Property_id not found for unit: %d", unit_id)
        return nil
    end

    -- 2. 查找对应的属性配置列表
    local property_list = find_property_list(property_id)
    if not property_list or #property_list == 0 then
        logger.error("Property not found for id: %s", property_id)
        return nil
    end

    -- 3. 计算各个属性的最终值
    return {
        hp = calculate_property(property_list, PROPERTY_TYPE.HP),
        attack = calculate_property(property_list, PROPERTY_TYPE.ATTACK),
        defense = calculate_property(property_list, PROPERTY_TYPE.DEFENSE)
    }
end

return M 