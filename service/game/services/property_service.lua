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
local function find_level_property_list(property_id, level)
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

-- 计算单个属性类型的最终值
local function calculate_property(property_list, property_type)
    local base_value = 0
    local percent = 0
    
    -- 遍历所有属性配置
    for _, prop in ipairs(property_list) do
        local prop_type = prop[1]
        local calc_type = prop[2]
        local value = prop[3]
        
        -- 确保value是数值类型
        if type(value) == "table" then
            -- 如果是表类型，尝试获取第一个数值
            value = value[1] or 0
        elseif type(value) == "string" then
            -- 如果是字符串，尝试转换为数值
            value = tonumber(value) or 0
        elseif type(value) ~= "number" then
            -- 其他类型都转为0
            value = 0
        end
        
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
function M.get_unit_level_property(unit_id, level)
    logger.info("Getting unit property - unit_id: %d, level: %d", unit_id, level)
    
    -- 1. 从unit配置中获取property_id，使用table_service
    local target_unit = table_service.get_unit_config(unit_id)
    if not target_unit then
        logger.error("Unit not found in config: %d", unit_id)
        return nil
    end
    
    local property_id = target_unit.property_id
    if not property_id then
        logger.error("Property_id not found for unit: %d", unit_id)
        return nil
    end

    -- 2. 查找对应的属性配置列表
    local property_list = find_level_property_list(property_id, level)
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
    end

    logger.info("Calculated unit property changes: %s", utils.table_to_string(property_changes))
    return property_changes
end

-- 查找战斗属性配置
local function find_battle_property_list(unit_id)
    logger.info("Finding battle property list for unit_id: %d", unit_id)
    
    -- 获取单位配置
    local target_unit = table_service.get_unit_config(unit_id)
    if not target_unit then
        logger.error("Unit not found in config: %d", unit_id)
        return {}
    end
    
    -- 获取战斗属性
    local battle_property = target_unit.battle_property
    if not battle_property then
        logger.error("Battle_property not found for unit: %d", unit_id)
        return {}
    end
    
    local result = {}
    -- 遍历战斗属性配置，转换为计算用的属性列表格式
    for prop_type, value in pairs(battle_property) do
        table.insert(result, {
            prop_type,        -- Property_type (枚举值)
            CALC_TYPE.VALUE,  -- 直接值
            value             -- 战斗属性值
        })
    end
    
    logger.info("Found battle property list: %s", utils.table_to_string(result))
    return result
end

-- 查找星级属性配置
local function find_star_property_list(star_id, star_level)
    logger.info("Finding star property list for star_id: %d, star_level: %d", star_id, star_level)
    
    -- 获取星级配置
    local star_config = table_service.get_companion_star_config(star_id, star_level)
    if not star_config then
        logger.error("Star config not found for star_id: %d, star_level: %d", star_id, star_level)
        return {}
    end
    
    -- 获取星级属性
    local attr = star_config.attr
    if not attr then
        logger.error("Attr not found in star config for star_id: %d, star_level: %d", star_id, star_level)
        return {}
    end
    
    local result = {}
    -- 遍历属性配置
    for _, prop in pairs(attr) do
        if #prop >= 2 then
            table.insert(result, {
                prop[1],           -- Property_type 
                CALC_TYPE.VALUE,   -- 默认为直接值
                prop[2]            -- Value
            })
        end
    end
    
    logger.info("Found star property list: %s", utils.table_to_string(result))
    return result
end

-- 获取单位战斗属性
function M.get_unit_battle_property(unit_id)
    logger.info("Getting unit battle property - unit_id: %d", unit_id)
    
    -- 1. 获取单位战斗属性配置列表
    local property_list = find_battle_property_list(unit_id)
    if not property_list or #property_list == 0 then
        logger.error("Battle property not found for unit_id: %d", unit_id)
        return {}
    end

    -- 2. 提取所有出现在配置中的属性类型
    local property_types = {}
    for _, prop in ipairs(property_list) do
        local prop_type = prop[1]
        if not property_types[prop_type] then
            property_types[prop_type] = true
        end
    end
    
    -- 3. 计算每个属性类型的最终值
    local property_changes = {}
    for prop_type, _ in pairs(property_types) do
        local value = calculate_property(property_list, prop_type)
        table.insert(property_changes, {
            prop_id = prop_type,
            value = value
        })
    end

    logger.info("Calculated battle property changes: %s", utils.table_to_string(property_changes))
    return property_changes
end

-- 获取伙伴星级属性
function M.get_companion_star_property(star_id, star_level)
    logger.info("Getting companion star property - star_id: %d, star_level: %d", star_id, star_level)
    
    -- 1. 获取星级属性配置列表
    local property_list = find_star_property_list(star_id, star_level)
    if not property_list or #property_list == 0 then
        logger.error("Star property not found for star_id: %d, star_level: %d", star_id, star_level)
        return {}
    end

    -- 2. 提取所有出现在配置中的属性类型
    local property_types = {}
    for _, prop in ipairs(property_list) do
        local prop_type = prop[1]
        if not property_types[prop_type] then
            property_types[prop_type] = true
        end
    end
    
    -- 3. 计算每个属性类型的最终值
    local property_changes = {}
    for prop_type, _ in pairs(property_types) do
        local value = calculate_property(property_list, prop_type)
        table.insert(property_changes, {
            prop_id = prop_type,
            value = value
        })
    end

    logger.info("Calculated star property changes: %s", utils.table_to_string(property_changes))
    return property_changes
end

-- 合并多个属性来源
function M.merge_properties(...)
    logger.info("Merging multiple property sources")
    
    -- 创建一个属性映射表，key是prop_id
    local prop_map = {}
    
    -- 遍历所有属性来源
    for _, prop_source in ipairs({...}) do
        if prop_source then
            for _, prop in ipairs(prop_source) do
                local prop_id = prop.prop_id
                
                -- 如果属性已存在，则累加值
                if prop_map[prop_id] then
                    prop_map[prop_id] = prop_map[prop_id] + prop.value
                else
                    -- 否则，初始化属性值
                    prop_map[prop_id] = prop.value
                end
            end
        end
    end
    
    -- 转换映射表为属性数组
    local merged_properties = {}
    for prop_id, value in pairs(prop_map) do
        table.insert(merged_properties, {
            prop_id = prop_id,
            value = value
        })
    end
    
    logger.info("Merged properties: %s", utils.table_to_string(merged_properties))
    return merged_properties
end

-- 获取单位所有属性（组合多个属性来源）
function M.get_unit_properties(unit_id, level, star_level)
    logger.info("Getting all unit properties - unit_id: %d, level: %d", unit_id, level)
    
    -- 获取单位配置
    local target_unit = table_service.get_unit_config(unit_id)
    if not target_unit then
        logger.error("Unit not found in config: %d", unit_id)
        return {}
    end
    
    -- 从单位配置中获取star_id
    local star_id = target_unit.star_id
    if not star_id then
        logger.warn("No star_id found for unit: %d, skipping star properties", unit_id)
    end
    
    -- 获取各种属性来源
    local level_properties = M.get_unit_level_property(unit_id, level)
    local battle_properties = M.get_unit_battle_property(unit_id)
    
    local star_properties = nil
    if star_id and star_level then
        star_properties = M.get_companion_star_property(star_id, star_level)
    end
    
    -- 合并所有属性来源
    return M.merge_properties(level_properties, battle_properties, star_properties)
end

return M