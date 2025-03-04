local skynet = require "skynet"
local logger = require "logger"
local config_loader = require "game.config_loader"
local enum = require "game.define.enum"

local M = {}

-- 配置缓存
local CONFIG_CACHE = {
    items = {},           -- 物品配置
    initial_items = {},   -- 初始物品配置
    units = {},          -- 单位配置
    properties = {},     -- 属性配置
    equips = {},          -- 装备配置
    equip_levels = {},   -- 装备等级配置
    equip_odds = {},     -- 装备概率配置
    exps = {},           -- 经验配置
    companion_stars = {} -- 伙伴星级配置
}

-- 计算table中的键值对数量
local function count_pairs(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- 初始化所有配置
function M.init()
    local configs_to_load = {
        {name = "item config", loader = M.load_item_config},
        {name = "initial item config", loader = M.load_initial_items},
        {name = "unit config", loader = M.load_unit_config},
        {name = "property config", loader = M.load_property_config},
        {name = "equipment configs", loader = M.load_equipment_configs},
        {name = "equipment level configs", loader = M.load_equipment_level_configs},
        {name = "equipment odds configs", loader = M.load_equipment_odds_configs},
        {name = "exp configs", loader = M.load_exp_configs},
        {name = "companion star configs", loader = M.load_companion_star_configs}
    }

    for _, config in ipairs(configs_to_load) do
        logger.info("Loading %s...", config.name)
        local ok = config.loader()
        if not ok then
            logger.error("Failed to load %s", config.name)
            return false
        end
    end

    logger.info("All configs loaded successfully")
    return true
end

-- 加载物品配置
function M.load_item_config()
    local data = config_loader.get_config("Dfw_item")
    if not data then
        return false
    end

    -- 转换配置格式
    for id, item_data in pairs(data) do
        local item_id = tonumber(item_data.Item_id)
        if item_id then
            CONFIG_CACHE.items[item_id] = {
                id = item_id,
                name = item_data.L_name,
                type = tonumber(item_data.Type) or 1,
                quality = tonumber(item_data.Qua) or 1,
                class = tonumber(item_data.Class) or 1,
                max_stack = tonumber(item_data.Max) or 99,
                description = item_data.L_des,
                icon = item_data.Icon,
                show = tonumber(item_data.Show) or 0,
                order = tonumber(item_data.Order) or 0,
                param = item_data.Param or {}
            }
        end
    end

    -- 添加测试物品配置
    CONFIG_CACHE.items[1001] = CONFIG_CACHE.items[1001] or {}
    CONFIG_CACHE.items[1001].effect_type = enum.EffectType.EFFECT_TYPE_EXP
    CONFIG_CACHE.items[1001].effect_value = 100

    CONFIG_CACHE.items[1002] = CONFIG_CACHE.items[1002] or {}
    CONFIG_CACHE.items[1002].effect_type = enum.EffectType.EFFECT_TYPE_EXP
    CONFIG_CACHE.items[1002].effect_value = 100

    CONFIG_CACHE.items[1003] = CONFIG_CACHE.items[1003] or {}
    CONFIG_CACHE.items[1003].effect_type = enum.EffectType.EFFECT_TYPE_EXP
    CONFIG_CACHE.items[1003].effect_value = 100

    CONFIG_CACHE.items[1004] = CONFIG_CACHE.items[1004] or {}
    CONFIG_CACHE.items[1004].effect_type = enum.EffectType.EFFECT_TYPE_EXP
    CONFIG_CACHE.items[1004].effect_value = 100

    CONFIG_CACHE.items[1005] = CONFIG_CACHE.items[1005] or {}
    CONFIG_CACHE.items[1005].effect_type = enum.EffectType.EFFECT_TYPE_EXP
    CONFIG_CACHE.items[1005].effect_value = 100

    CONFIG_CACHE.items[2012] = CONFIG_CACHE.items[2012] or {}
    CONFIG_CACHE.items[2012].effect_type = enum.EffectType.EFFECT_TYPE_GOLD
    CONFIG_CACHE.items[2012].effect_value = 1000

    logger.info("Item config loaded: %d items", count_pairs(CONFIG_CACHE.items))
    return true
end

-- 加载初始物品配置
function M.load_initial_items()
    local data = config_loader.get_config("Dfw_Initial")
    if not data then
        return false
    end

    -- 获取第一个玩家的配置
    local player_config = data["1"]
    if not player_config or not player_config.Item then
        logger.error("Invalid initial config format")
        return false
    end

    -- 转换配置格式
    for _, item_data in ipairs(player_config.Item) do
        table.insert(CONFIG_CACHE.initial_items, {
            item_id = tonumber(item_data[1]),
            count = tonumber(item_data[2] or 1)
        })
    end
    logger.info("Initial items loaded: %d items", count_pairs(CONFIG_CACHE.initial_items))
    return true
end

-- 加载单位配置
function M.load_unit_config()
    local data = config_loader.get_config("Dfw_unit")
    if not data then
        return false
    end

    -- 转换配置格式
    for _, unit_data in pairs(data) do
        local unit_id = tonumber(unit_data.Unit_id)
        if unit_id then
            CONFIG_CACHE.units[unit_id] = {
                id = unit_id,
                name = unit_data.L_Name,
                type = tonumber(unit_data.Type) or 0,
                property_id = tonumber(unit_data.Property_id),
                quality = tonumber(unit_data.Qua) or 0,
                star = tonumber(unit_data.Star) or 0,
                icon = unit_data.Icon,
                model = unit_data.Action,
                model_dfw = unit_data.Action_dfw,
                model_scale_battle = tonumber(unit_data.Model_scale_battle) or 10000,
                model_scale_dfw = tonumber(unit_data.Model_scale_dfw) or 10000,
                battle_property = unit_data.Battle_property or {},
                skill_battle = unit_data.Skill_battle or {},
                skill_dfw = unit_data.skill_dfw or {},
                shards = unit_data.Shards or {},
                disassemble = unit_data.Disassemble or {}

            }
        end
    end

    logger.info("Unit config loaded: %d units", count_pairs(CONFIG_CACHE.units))
    return true
end

-- 加载属性配置
function M.load_property_config()
    local data = config_loader.get_config("Dfw_property")
    if not data then
        return false
    end

    -- 转换配置格式
    for _, prop_data in pairs(data) do
        local property_id = tonumber(prop_data.Property_id)
        local level = tonumber(prop_data.Level)
        if property_id and level then
            local key = string.format("%d_%d", property_id, level)
            CONFIG_CACHE.properties[key] = {
                id = tonumber(prop_data.Id),
                property_id = property_id,
                level = level,
                property = prop_data.Property or {},  -- 属性数组 [[type,calc_type,value], ...]
            }
        end
    end

    logger.info("Property config loaded: %d properties", count_pairs(CONFIG_CACHE.properties))
    return true
end

-- 获取物品配置
function M.get_item_config(item_id)
    if not CONFIG_CACHE.items then
        M.load_item_config()
    end
    
    return CONFIG_CACHE.items[tonumber(item_id)]
end

-- 获取初始物品配置
function M.get_initial_items()
    return CONFIG_CACHE.initial_items
end

-- 获取单位配置
function M.get_unit_config(unit_id)
    return CONFIG_CACHE.units[unit_id]
end

-- 获取属性配置
function M.get_property_config(property_id, level)
    local key = string.format("%d_%d", property_id, level)
    return CONFIG_CACHE.properties[key]
end

-- 获取合成配置
function M.get_compose_config(target_id)
    logger.debug("Getting compose config for target_id: %s", tostring(target_id))
    
    -- 1. 从 Dfw_item.json 获取目标物品配置
    local item_config = M.get_item_config(target_id)
    if not item_config then
        logger.debug("Item config not found for target_id: %s", tostring(target_id))
        return nil
    end

    -- 2. 验证物品类型是否为 PARTNER
    if not item_config.type or item_config.type ~= enum.ItemType.ITEM_TYPE_PARTNER then
        logger.debug("Item type is not PARTNER: %s", tostring(item_config.type))
        return nil
    end

    -- 3. 从 Param 二维数组中获取 unit_id
    -- Param 格式: [[4301]]
    if not item_config.param or not item_config.param[1] then
        logger.debug("Item param is nil or invalid")
        return nil
    end
    
    local unit_id = item_config.param[1][1]
    if not unit_id then
        logger.debug("Unit ID not found in param")
        return nil
    end

    -- 记录关键信息
    logger.debug("Found unit_id: %s from item param", tostring(unit_id))

    -- 4. 从 Dfw_unit.json 获取对应单位配置
    local unit_config = M.get_unit_config(unit_id)
    if not unit_config then
        logger.debug("Unit config not found for unit_id: %s", tostring(unit_id))
        return nil
    end

    -- 5. 从 Shards 数组中获取所需碎片数量
    -- Shards 格式: [4301, 20]
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

    -- 记录找到的碎片信息
    logger.debug("Found shard_id: %s, count: %s", tostring(shard_id), tostring(shard_count))

    -- 6. 构造合成配置
    return {
        target_id = target_id,
        materials = {
            {
                item_id = shard_id,  -- 使用碎片ID
                count = shard_count  -- 所需碎片数量
            }
        }
    }
end

-- 获取分解配置
function M.get_decompose_config(target_id)
    logger.debug("Getting decompose config for target_id: %s", tostring(target_id))
    
    -- 1. 从 Dfw_item.json 获取目标物品配置
    local item_config = M.get_item_config(target_id)
    if not item_config then
        logger.debug("Item config not found for target_id: %s", tostring(target_id))
        return nil
    end

    -- 2. 验证物品类型是否为 PARTNER
    if not item_config.type or item_config.type ~= enum.ItemType.ITEM_TYPE_PARTNER then
        logger.debug("Item type is not PARTNER: %s", tostring(item_config.type))
        return nil
    end

    -- 3. 从 Param 二维数组中获取 unit_id
    -- Param 格式: [[4301]]
    if not item_config.param or not item_config.param[1] then
        logger.debug("Item param is nil or invalid")
        return nil
    end
    
    local unit_id = item_config.param[1][1]
    if not unit_id then
        logger.debug("Unit ID not found in param")
        return nil
    end

    -- 记录关键信息
    logger.debug("Found unit_id: %s from item param", tostring(unit_id))

    -- 4. 从 Dfw_unit.json 获取对应单位配置
    local unit_config = M.get_unit_config(unit_id)
    if not unit_config then
        logger.debug("Unit config not found for unit_id: %s", tostring(unit_id))
        return nil
    end

    -- 5. 从 disassemble 数组中获取分解信息
    -- disassemble 格式: [4301, 20]
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

    -- 记录找到的分解信息
    logger.debug("Found result_id: %s, count: %s", tostring(result_id), tostring(result_count))

    -- 6. 构造分解配置
    return {
        target_id = target_id,
        result_items = {
            {
                item_id = result_id,     -- 分解获得的物品ID
                count = result_count     -- 分解获得的物品数量
            }
        }
    }
end

-- 加载装备配置
function M.load_equipment_configs()
    local data = config_loader.get_config("Dfw_equip")
    if not data then
        return false
    end     

    local equips = {}
    for _, config in ipairs(data) do
        local id = tonumber(config.Equip_id)
        if id then
            equips[id] = {
                id = id,
                name = config.L_name,
                quality = tonumber(config.Qua) or 1,
                part = tonumber(config.Part) or 1,
                icon = config.Icon,
                split = tonumber(config.Split) or 0,
                power = tonumber(config.Power) or 0,
                attr_num = config.Attr_num or {},
                attr = config.Attr or {}
            }
        end
    end

    CONFIG_CACHE.equips = equips
    logger.info("Loaded %d equipment configs", count_pairs(equips))
    return equips
end

-- 获取装备配置
function M.get_equipment_config(equip_id)
    if not CONFIG_CACHE.equips then
        M.load_equipment_configs()
    end
    return CONFIG_CACHE.equips and CONFIG_CACHE.equips[equip_id]
end

-- 获取所有装备配置
function M.get_all_equipment_configs()
    if not CONFIG_CACHE.equips then
        M.load_equipment_configs()
    end
    return CONFIG_CACHE.equips
end

-- 加载装备等级配置
function M.load_equipment_level_configs()
    local data = config_loader.get_config("Dfw_equip_level")
    if not data then
        return false
    end

    local levels = {}
    for _, config in ipairs(data) do
        local level = tonumber(config.Level)
        if level then
            levels[level] = {
                level = level,
                qua_1 = config.Qua_1 or {},
                qua_2 = config.Qua_2 or {},
                qua_3 = config.Qua_3 or {},
                qua_4 = config.Qua_4 or {},
                qua_5 = config.Qua_5 or {},
                qua_6 = config.Qua_6 or {},
                qua_7 = config.Qua_7 or {},
                qua_8 = config.Qua_8 or {},
                qua_9 = config.Qua_9 or {}
            }
        end
    end

    CONFIG_CACHE.equip_levels = levels
    logger.info("Loaded %d equipment level configs", count_pairs(levels))
    return levels
end

-- 获取装备等级配置
function M.get_equipment_level_config(level)
    if not CONFIG_CACHE.equip_levels then
        M.load_equipment_level_configs()
    end
    return CONFIG_CACHE.equip_levels and CONFIG_CACHE.equip_levels[level]
end

-- 获取所有装备等级配置
function M.get_all_equipment_level_configs()
    -- 如果没有从配置文件加载，提供一个默认配置
    if not CONFIG_CACHE.equip_levels or next(CONFIG_CACHE.equip_levels) == nil then
        -- 创建默认的装备等级配置
        CONFIG_CACHE.equip_levels = {}
        
        -- 添加10个等级的配置
        for level = 1, 10 do
            CONFIG_CACHE.equip_levels[level] = {
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
    end
    
    return CONFIG_CACHE.equip_levels
end

-- 获取指定等级的装备配置
function M.get_equipment_level_config(level)
    local configs = M.get_all_equipment_level_configs()
    return configs and configs[level]
end

-- 加载装备概率配置
function M.load_equipment_odds_configs()
    local data = config_loader.get_config("Dfw_equip_odds")
    if not data then
        return false
    end

    local odds = {}
    for _, config in ipairs(data) do
        local level = tonumber(config.Level)
        if level then
            odds[level] = {
                level = level,
                exp = tonumber(config.Exp) or 0,
                qua_1 = tonumber(config.Qua_1) or 0,
                qua_2 = tonumber(config.Qua_2) or 0,
                qua_3 = tonumber(config.Qua_3) or 0,
                qua_4 = tonumber(config.Qua_4) or 0,
                qua_5 = tonumber(config.Qua_5) or 0,
                qua_6 = tonumber(config.Qua_6) or 0,
                qua_7 = tonumber(config.Qua_7) or 0,
                qua_8 = tonumber(config.Qua_8) or 0,
                qua_9 = tonumber(config.Qua_9) or 0
            }
        end
    end

    CONFIG_CACHE.equip_odds = odds
    logger.info("Loaded %d equipment odds configs", count_pairs(odds))
    return odds
end

-- 获取装备概率配置
function M.get_equipment_odds_config(level)
    if not CONFIG_CACHE.equip_odds then
        M.load_equipment_odds_configs()
    end
    return CONFIG_CACHE.equip_odds and CONFIG_CACHE.equip_odds[level]
end

-- 获取所有装备概率配置
function M.get_all_equipment_odds_configs()
    if not CONFIG_CACHE.equip_odds then
        M.load_equipment_odds_configs()
    end
    return CONFIG_CACHE.equip_odds
end

-- 加载经验配置
function M.load_exp_configs()
    local data = config_loader.get_config("Dwf_exp")
    if not data then
        return false
    end

    local exps = {}
    for _, config in ipairs(data) do
        local level = tonumber(config.Level)
        if level then
            exps[level] = {
                level = level,
                exp = tonumber(config.Exp) or 0,
                total_exp = tonumber(config.Total_exp) or 0,
                -- 添加其他需要的字段
            }
        end
    end

    CONFIG_CACHE.exps = exps
    logger.info("Loaded %d exp configs", count_pairs(exps))
    return exps
end

-- 获取经验配置
function M.get_exp_config(level)
    if not CONFIG_CACHE.exps then
        M.load_exp_configs()
    end
    return CONFIG_CACHE.exps and CONFIG_CACHE.exps[level]
end

-- 获取所有经验配置
function M.get_all_exp_configs()
    if not CONFIG_CACHE.exps then
        M.load_exp_configs()
    end
    return CONFIG_CACHE.exps
end

-- 加载伙伴星级配置
function M.load_companion_star_configs()
    local data = config_loader.get_config("Dfw_companion_star")
    if not data then
        return false
    end

    local stars = {}
    for _, config in ipairs(data) do
        local star = tonumber(config.Star)
        if star then
            stars[star] = {
                star = star,
                attrs = config.Attrs or {},
                materials = config.Materials or {},
                coins = tonumber(config.Coins) or 0,
                -- 添加其他需要的字段
            }
        end
    end

    CONFIG_CACHE.companion_stars = stars
    logger.info("Loaded %d companion star configs", count_pairs(stars))
    return stars
end

-- 获取伙伴星级配置
function M.get_companion_star_config(star)
    if not CONFIG_CACHE.companion_stars then
        M.load_companion_star_configs()
    end
    return CONFIG_CACHE.companion_stars and CONFIG_CACHE.companion_stars[star]
end

-- 获取所有伙伴星级配置
function M.get_all_companion_star_configs()
    if not CONFIG_CACHE.companion_stars then
        M.load_companion_star_configs()
    end
    return CONFIG_CACHE.companion_stars
end

-- 添加缺失的装备配置获取方法
function M.get_config_value(config_name, key, default_value)
    local config = M.get_config(config_name)
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

-- 获取装备基础配置
function M.get_equip_base_config()
    return {
        min_quality = 1,
        max_quality = 5,
        min_level = 1,
        max_level = 100,
        parts = {1, 2, 3, 4, 5, 6},  -- 可用装备部位
        quality_odds = {60, 25, 10, 4, 1}  -- 各品质概率
    }
end

-- 获取随机装备模板
function M.get_random_equip_template(part)
    local templates = {
        [1] = {
            name = "头盔",
            item_id_base = 2001,
            slots = {1},
            props = {
                defense = {10, 20, 30, 40, 50},
                hp = {50, 100, 150, 200, 250}
            }
        },
        [2] = {
            name = "护甲",
            item_id_base = 2002,
            slots = {2},
            props = {
                defense = {20, 40, 60, 80, 100},
                hp = {100, 200, 300, 400, 500}
            }
        },
        [3] = {
            name = "武器",
            item_id_base = 2003,
            slots = {3},
            props = {
                attack = {30, 60, 90, 120, 150},
                crit = {1, 2, 3, 4, 5}
            }
        },
        [4] = {
            name = "鞋子",
            item_id_base = 2004,
            slots = {4},
            props = {
                speed = {10, 20, 30, 40, 50},
                dodge = {1, 2, 3, 4, 5}
            }
        },
        [5] = {
            name = "手套",
            item_id_base = 2005,
            slots = {5},
            props = {
                attack_speed = {5, 10, 15, 20, 25},
                accuracy = {1, 2, 3, 4, 5}
            }
        },
        [6] = {
            name = "项链",
            item_id_base = 2006,
            slots = {6},
            props = {
                magic_attack = {20, 40, 60, 80, 100},
                mp = {50, 100, 150, 200, 250}
            }
        }
    }
    
    if part and part > 0 and part <= 6 then
        return templates[part]
    else
        -- 随机选择一个部位
        local parts = {1, 2, 3, 4, 5, 6}
        local idx = math.random(1, #parts)
        return templates[parts[idx]]
    end
end

return M