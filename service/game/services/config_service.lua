local skynet = require "skynet"
local logger = require "logger"
local config_loader = require "game.config_loader"
local item_model = require "models.item_model"
local utils = require "utils"

local M = {}

-- 配置缓存
local CONFIG_CACHE = {
    items = {},           -- 物品配置
    initial_items = {},   -- 初始物品配置
    units = {},          -- 单位配置
    properties = {},     -- 属性配置
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
        {name = "物品配置", loader = M.load_item_config},
        {name = "初始物品配置", loader = M.load_initial_items},
        {name = "单位配置", loader = M.load_unit_config},
        {name = "属性配置", loader = M.load_property_config}
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
                order = tonumber(item_data.Order) or 0
            }
        end
    end

    -- 添加测试物品配置
    CONFIG_CACHE.items[1001] = CONFIG_CACHE.items[1001] or {}
    CONFIG_CACHE.items[1001].effect_type = item_model.EFFECT_TYPE.EXP
    CONFIG_CACHE.items[1001].effect_value = 100
    CONFIG_CACHE.items[1001].max_stack = 10000

    CONFIG_CACHE.items[2012] = CONFIG_CACHE.items[2012] or {}
    CONFIG_CACHE.items[2012].effect_type = item_model.EFFECT_TYPE.GOLD
    CONFIG_CACHE.items[2012].effect_value = 1000
    CONFIG_CACHE.items[2012].max_stack = 10000

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
    local data = config_loader.get_config("Dfw_Unit")
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
                skill_dfw = unit_data.skill_dfw or {}
            }
        end
    end

    logger.info("Unit config loaded: %d units", count_pairs(CONFIG_CACHE.units))
    return true
end

-- 加载属性配置
function M.load_property_config()
    local data = config_loader.get_config("Dfw_Property")
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
    return CONFIG_CACHE.items[item_id]
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

return M