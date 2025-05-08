local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local enum = require "enum"
local config_service = require "services.config_service"

local M = {}

-- 获取所有单位配置
function M.get_unit_configs()
    local configs = config_service.get_config("units")
    if not configs then
        logger.error("Failed to get unit configs")
        return nil
    end
    return configs
end

-- 获取特定单位配置
function M.get_unit_config(unit_id)
    local configs = M.get_unit_configs()
    if not configs then
        return nil
    end
    return configs[unit_id]
end

-- 获取伙伴星级配置
function M.get_companion_star_config(star_id, star_level)
    local configs = config_service.get_config("companion_stars")
    if not configs then
        logger.error("Failed to get companion star configs")
        return nil
    end
    
    local key = string.format("%d_%d", star_id, star_level)
    return configs[key]
end

-- 获取属性配置
function M.get_property_config(property_id, level)
    level = level or 1
    
    local configs = config_service.get_config("properties")
    if not configs then
        logger.error("Failed to get property configs")
        return nil
    end
    
    local key = string.format("%d_%d", property_id, level)
    return configs[key]
end

-- 获取属性成长配置
function M.get_property_growth_config(unit_id)
    local configs = config_service.get_config("property_growth")
    if not configs then
        logger.error("Failed to get property growth configs")
        return {}
    end
    
    return configs[unit_id] or {}
end

-- 获取伙伴最大等级
function M.get_max_partner_level()
    local configs = config_service.get_config("experience")
    if not configs then
        logger.error("Failed to get experience configs")
        return 100 -- 默认最大等级
    end
    
    local max_level = 1
    for level, _ in pairs(configs) do
        if tonumber(level) > max_level then
            max_level = tonumber(level)
        end
    end
    
    return max_level
end

-- 获取伙伴最大星级
function M.get_max_partner_star(star_id)
    local configs = config_service.get_config("companion_stars")
    if not configs then
        logger.error("Failed to get companion star configs")
        return 5 -- 默认最大星级
    end
    
    local max_level = 0
    for key, config in pairs(configs) do
        if config.star_id == star_id and config.level > max_level then
            max_level = config.level
        end
    end
    
    return max_level
end

-- 获取伙伴升级消耗
function M.get_partner_level_up_cost(unit_id, level)
    logger.info("get_partner_level_up_cost unit_id=%d, level=%d", unit_id, level)
    local unit_config = M.get_unit_config(tonumber(unit_id))
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return nil
    end

    local exp_config = M.get_exp_config(level)
    if not exp_config then
        logger.error("Failed to get exp config for level: %d", level)
        return nil
    end

    -- 根据单位类型返回对应的消耗值
    local exp_info = nil
    if unit_config.type == enum.UnitType.UNIT_TYPE_HERO then
        exp_info = exp_config.hero_exp
    elseif unit_config.type == enum.UnitType.UNIT_TYPE_PARTNER then
        exp_info = exp_config.partner_exp
    else
        logger.error("Invalid unit type: %d for unit_id: %d", unit_config.type, unit_id)
        return nil
    end

    if not exp_info or not exp_info.item_id or not exp_info.value then
        logger.error("Invalid exp info for level: %d", level)
        return nil
    end

    return {
        {
            item_id = exp_info.item_id,
            count = exp_info.value
        }
    }
end

-- 获取伙伴升星消耗
function M.get_partner_star_up_cost(unit_id, star)
    local configs = config_service.get_config("companion_stars")
    if not configs then
        logger.error("Failed to get partner star up configs")
        return {}
    end
    
    local unit_config = M.get_unit_config(tonumber(unit_id))
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return {}
    end
    
    local star_id = unit_config.star_id or 1
    local key = string.format("%d_%d", star_id, star)
    local cost_config = configs[key]
    if not cost_config then
        return {}
    end
    
    logger.info("cost_config: %s", utils.table_to_string(cost_config))
    
    local result = {}
    -- consume 是一个数组，每个元素是 {item_id, count} 格式
    if cost_config.consume then
        for _, consume_item in ipairs(cost_config.consume) do
            table.insert(result, {
                item_id = tonumber(consume_item[1]),
                count = tonumber(consume_item[2])
            })
        end
    end
    
    return result
end

-- 按品质筛选伙伴
function M.get_partners_by_quality(quality)
    local configs = M.get_unit_configs()
    if not configs then
        return {}
    end
    
    local result = {}
    for id, config in pairs(configs) do
        if config.type == 4 and config.quality == quality then
            table.insert(result, config)
        end
    end
    
    return result
end

-- 按种族筛选伙伴
function M.get_partners_by_race(race)
    local configs = M.get_unit_configs()
    if not configs then
        return {}
    end
    
    local result = {}
    for id, config in pairs(configs) do
        if config.type == 4 and config.race == race then
            table.insert(result, config)
        end
    end
    
    return result
end

-- 获取伙伴碎片分解配置
function M.get_partner_shard_config(unit_id)
    local configs = config_service.get_config("partner_shards")
    if not configs then
        logger.error("Failed to get partner shard configs")
        return nil
    end
    
    local unit_config = M.get_unit_config(unit_id)
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return nil
    end
    
    local quality = unit_config.quality or 1
    return configs[quality] or configs[1]
end

-- 获取伙伴分解配置
function M.get_partner_disassemble_config(quality)
    local configs = config_service.get_config("partner_disassemble")
    if not configs then
        logger.error("Failed to get partner disassemble configs")
        return nil
    end
    
    return configs[quality] or configs[1]
end

-- 获取默认解锁碎片数量
function M.get_default_unlock_fragments()
    local configs = config_service.get_config("game_constants")
    if not configs or not configs.default_unlock_fragments then
        logger.error("Failed to get default unlock fragments count")
        return 30 -- 默认解锁碎片数量
    end
    
    return configs.default_unlock_fragments
end

-- 获取所有物品配置
function M.get_item_configs()
    local configs = config_service.get_config("items")
    if not configs then
        logger.error("Failed to get item configs")
        return {}
    end
    return configs
end

-- 获取特定物品配置
function M.get_item_config(item_id)
    local configs = M.get_item_configs()
    if not configs then
        return nil
    end
    
    return configs[item_id]
end

-- 获取主角单位ID
function M.get_hero_unit_id()
    local configs = M.get_unit_configs()
    if not configs then
        logger.error("Failed to get unit configs")
        return 1  -- 默认返回ID为1作为主角ID
    end
    
    -- 遍历所有单位配置，查找类型为UNIT_TYPE_HERO的单位
    for id, config in pairs(configs) do
        if config.type == enum.UnitType.UNIT_TYPE_HERO then
            logger.info("Found hero unit with ID: %d", id)
            return tonumber(id)
        end
    end
    
    logger.warn("No hero unit found in configuration, using default ID 1")
    return 1  -- 如果没有找到，返回默认ID 1
end

-- 抽取共用的物品和单位配置获取逻辑
local function get_partner_unit_config(target_id)
    -- 1. 获取物品配置
    local item_config = M.get_item_config(target_id)
    if not item_config then
        logger.debug("Item config not found for target_id: %s", tostring(target_id))
        return nil
    end

    -- 2. 验证物品类型
    if not item_config.type or item_config.type ~= enum.ItemType.ITEM_TYPE_PARTNER then
        logger.debug("Item type is not PARTNER: %s", tostring(item_config.type))
        return nil
    end

    -- 3. 获取unit_id
    if not item_config.param or not item_config.param[1] then
        logger.debug("Item param is nil or invalid")
        return nil
    end
    
    local unit_id = item_config.param[1][1]
    if not unit_id then
        logger.debug("Unit ID not found in param")
        return nil
    end

    -- 4. 获取单位配置
    local unit_config = M.get_unit_config(unit_id)
    if not unit_config then
        logger.debug("Unit config not found for unit_id: %s", tostring(unit_id))
        return nil
    end

    return unit_config
end

-- 获取合成配置
function M.get_compose_config(target_id)
    logger.debug("Getting compose config for target_id: %s", tostring(target_id))
    
    -- 获取单位配置
    local unit_config = get_partner_unit_config(target_id)
    if not unit_config then
        return nil
    end

    -- 获取碎片信息
    if not unit_config.shards then
        logger.debug("Unit Shards data not found")
        return nil
    end
    
    local shard_id = unit_config.shards[1]
    local shard_count = unit_config.shards[2]
    if not shard_id or not shard_count then
        logger.debug("Shard ID or count not found in unit config")
        return nil
    end

    -- 构造合成配置
    return {
        target_id = target_id,
        materials = {
            {
                item_id = shard_id,
                count = shard_count
            }
        }
    }
end

-- 获取分解配置
function M.get_decompose_config(target_id)
    logger.debug("Getting decompose config for target_id: %s", tostring(target_id))
    
    -- 获取单位配置
    local unit_config = get_partner_unit_config(target_id)
    if not unit_config then
        return nil
    end

    -- 获取分解信息
    if not unit_config.disassemble then
        logger.debug("Unit disassemble data not found")
        return nil
    end

    local result_id = unit_config.disassemble[1]
    local result_count = unit_config.disassemble[2]
    if not result_id or not result_count then
        logger.debug("Result ID or count not found in unit disassemble config")
        return nil
    end

    -- 构造分解配置
    return {
        target_id = target_id,
        result_items = {
            {
                item_id = result_id,
                count = result_count
            }
        }
    }
end

-- 获取所有装备等级配置
function M.get_all_equipment_level_configs() 
    -- 从配置服务获取装备等级配置
    local configs = config_service.get_config("equip_levels")
    
    -- 如果配置不存在，提供一个默认配置
    if not configs or next(configs) == nil then
        -- 创建默认的装备等级配置
        configs = {}
        
        -- 添加10个等级的配置
        for level = 1, 10 do
            configs[level] = {
                level = level,
                upgrade_time = level * 30,  -- 每级升级时间递增
                item_id = 1005,  -- 升级所需道具ID
                item_count = level * 5,  -- 每级所需道具数量递增
                quality_odds = {
                    60 - level * 2,  -- 白色品质概率
                    25 + level,      -- 绿色品质概率
                    10 + level * 0.5, -- 蓝色品质概率
                    4 + level * 0.3,  -- 紫色品质概率
                    1 + level * 0.2   -- 橙色品质概率
                }
            }
        end
        
        logger.info("Using default equipment level configs")
    end
    
    return configs
end

-- 获取指定等级的装备配置
function M.get_equipment_level_config(level)
    local configs = M.get_all_equipment_level_configs()
    return configs and configs[level]
end

-- 获取初始物品配置
function M.get_initial_items()
    -- 从config_service获取初始物品配置
    local initial_items = config_service.get_config("initial_items")
    if initial_items and next(initial_items) then
        return initial_items
    end
    
    return {}
end

-- 获取装备配置
function M.get_equipment_config(equip_id)
    local configs = M.get_all_equipment_configs()
    if not configs then
        return nil
    end
    return configs[equip_id]
end

-- 获取所有装备配置
function M.get_all_equipment_configs()
    local configs = config_service.get_config("equips")
    if not configs then
        logger.error("Failed to get equipment configs")
        return nil
    end
    return configs
end

-- 获取装备概率配置
function M.get_equipment_odds_config(level)
    local configs = M.get_all_equipment_odds_configs()
    if not configs then
        return nil
    end
    return configs[level]
end

-- 获取所有装备概率配置
function M.get_all_equipment_odds_configs()
    local configs = config_service.get_config("equip_odds")
    if not configs then
        logger.error("Failed to get equipment odds configs")
        return nil
    end
    return configs
end

-- 获取经验配置
function M.get_exp_config(level)
    local configs = M.get_all_exp_configs()
    if not configs then
        return nil
    end
    return configs[level]
end

-- 获取所有经验配置
function M.get_all_exp_configs()
    local configs = config_service.get_config("experience")
    if not configs then
        logger.error("Failed to get experience configs")
        return nil
    end
    return configs
end

-- 获取配置值
function M.get_config_value(config_name, key, default_value)
    local config = config_service.get_config(config_name)
    if not config then
        logger.warn("Config '%s' not found", config_name)
        return default_value
    end
    
    local value = config[key]
    if value == nil then
        logger.warn("Key '%s' not found in config '%s'", key, config_name)
        return default_value
    end
    
    return value
end

-- 获取配置值
function M.get_config_values(config_name)
    return config_service.get_config(config_name)
end

-- 获取随机格子配置
function M.get_cell_random_configs()
    local configs = config_service.get_config("cell_random_events")
    if not configs then
        logger.error("Failed to get cell_random_events configs")
        return {}
    end
    return configs
end

-- 获取特定地图ID的随机格子配置
function M.get_cell_random_configs_by_map_id(map_id)
    local configs = M.get_cell_random_configs()
    if not configs then
        return {}
    end
    
    local result = {}
    for _, config in pairs(configs) do
        if config.map_id == map_id then
            table.insert(result, config)
        end
    end
    
    return result
end


return M 