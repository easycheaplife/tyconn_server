local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local item_dao = require "dao.item_dao"
local bag_model = require "models.bag_model"
local item_model = require "models.item_model"
local table_service = require "services.table_service"
local enum = require "enum"

local M = {}

-- 计算类型
local CALC_TYPE = {
    VALUE = 1,    -- 直接值
    PERCENT = 2   -- 万分比
}

-- 查找属性配置
local function find_property_list(property_id, level)
    logger.info("Finding property list for id: %s, level: %d", property_id, level)
    -- 使用table_service代替直接使用config_service
    local config = table_service.get_property_config(property_id, level)
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
    
    -- 1. 从unit配置中获取property_id，使用table_service
    local target_unit = table_service.get_unit_config(unit_id)
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

    -- 3. 提取所有出现在配置中的属性类型
    local property_types = {}
    for _, prop in ipairs(property_list) do
        local prop_type = prop[1]
        if not property_types[prop_type] then
            property_types[prop_type] = true
        end
    end
    
    -- 4. 计算每个属性类型的最终值并以PropertyChange格式返回
    local property_changes = {}
    for prop_type, _ in pairs(property_types) do
        local value = calculate_property(property_list, prop_type)
        table.insert(property_changes, {
            prop_id = prop_type,
            value = value
        })
        logger.info("Calculated unit property changes: %s", utils.table_to_string(property_changes))
    end

    logger.info("Calculated unit property changes: %s", utils.table_to_string(property_changes))
    return property_changes
end

return M