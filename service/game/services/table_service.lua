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
    local unit_config = M.get_unit_config(tonumber(unit_id))
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return nil
    end

    local configs = config_service.get_config("experience")
    if not configs then
        logger.error("Failed to get exp configs")
        return nil
    end

    local exp_config = configs[level]
    if not exp_config then
        logger.error("Failed to get exp config for level: %d", level)
        return nil
    end

    -- 根据单位类型返回对应的消耗值
    local exp_count = 0
    if unit_config.type == enum.UnitType.UNIT_TYPE_HERO then  -- UNIT_TYPE_HERO
        exp_count = exp_config.hero_id
    elseif unit_config.type == enum.UnitType.UNIT_TYPE_PARTNER then  -- UNIT_TYPE_PARTNER
        exp_count = exp_config.partner_id
    else
        logger.error("Invalid unit type: %d for unit_id: %d", unit_config.type, unit_id)
        return nil
    end

    return {
        {
            item_id = enum.SpecialItemID.SPECIAL_ITEM_ID_EXP,
            count = exp_count
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

-- 获取战力计算配置
function M.get_power_calculation_config()
    local configs = config_service.get_config("power_calculation")
    if not configs then
        logger.error("Failed to get power calculation configs")
        -- 返回默认战力计算配置
        return {
            prop_multipliers = {
                [enum.PropType.PROP_HP] = 0.1,  -- 生命值
                [enum.PropType.PROP_MP] = 0.05, -- 魔法值
                [enum.PropType.PROP_ATTACK] = 2.0,  -- 攻击力
                [enum.PropType.PROP_DEFENSE] = 1.5,  -- 防御力
                [enum.PropType.PROP_SPEED] = 1.0,  -- 速度
                [enum.PropType.PROP_CRIT_RATE] = 3.0   -- 暴击率
            },
            level_multiplier = 10,
            star_multiplier = 100,
            quality_multiplier = 200
        }
    end
    
    return configs
end

-- 获取默认属性配置
function M.get_default_property_config()
    local configs = config_service.get_config("default_properties")
    if not configs then
        logger.error("Failed to get default property configs")
        -- 返回默认属性配置
        return {
            base_hp = 100,
            base_mp = 50,
            base_attack = 10,
            base_defense = 5,
            base_speed = 100,
            hit_rate = 5,
            dodge_rate = 3,
            crit_rate = 5,
            crit_dmg = 150
        }
    end
    
    return configs
end

-- 获取成长公式配置
function M.get_growth_formula_config()
    local configs = config_service.get_config("growth_formula")
    if not configs then
        logger.error("Failed to get growth formula configs")
        -- 返回默认成长公式配置
        return {
            star_bonus_rate = 0.1,
            quality_bonus_rate = 0.2,
            level_growth_rate = 0.1,
            combat_quality_bonus_rate = 0.5
        }
    end
    
    return configs
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

return M 