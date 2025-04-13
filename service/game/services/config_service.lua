local skynet = require "skynet"
local logger = require "logger"
local config_loader = require "game.config_loader"
local enum = require "enum"
local utils = require "utils"

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
    companion_stars = {}, -- 伙伴星级配置
    cell_data = {},      -- 大富翁格子数据
    cell_events = {},    -- 大富翁格子事件
    cell_random_events = {}, -- 大富翁随机事件
    monopoly = {}        -- 大富翁章节配置
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
        {name = "companion star configs", loader = M.load_companion_star_configs},
        {name = "monopoly cell data", loader = M.load_cell_data_config},
        {name = "monopoly cell events", loader = M.load_cell_events_config},
        {name = "monopoly chapter config", loader = M.load_monopoly_config},
        {name = "monopoly random events", loader = M.load_cell_random_events_config}
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
    CONFIG_CACHE.items[2011] = CONFIG_CACHE.items[2011] or {}
    CONFIG_CACHE.items[2011].effect_type = enum.EffectType.EFFECT_TYPE_EXP
    CONFIG_CACHE.items[2011].effect_value = 100

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
                disassemble = unit_data.Disassemble or {},
                star_id = tonumber(unit_data.Star_id) or 0,
                race = tonumber(unit_data.Race) or 0,
                forte = tonumber(unit_data.Forte) or 0
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

-- 加载经验配置
function M.load_exp_configs()
    local data = config_loader.get_config("Dfw_exp")
    if not data then
        return false
    end

    local exps = {}
    for id, config in pairs(data) do
        local level = tonumber(config.Id) or 0
        if level > 0 then
            -- 处理英雄经验配置
            local hero_exp = config.Hero_exp or {}
            local hero_exp_item_id = tonumber(hero_exp[1]) or 0
            local hero_exp_value = tonumber(hero_exp[2]) or 0
            
            -- 处理伙伴经验配置
            local partner_exp = config.Partner_exp or {}
            local partner_exp_item_id = tonumber(partner_exp[1]) or 0
            local partner_exp_value = tonumber(partner_exp[2]) or 0
            
            exps[level] = {
                id = level,
                hero_exp = {
                    item_id = hero_exp_item_id,
                    value = hero_exp_value
                },
                partner_exp = {
                    item_id = partner_exp_item_id,
                    value = partner_exp_value
                },
                partner_num = tonumber(config.Partner_num) or 0,
                cultivation_level = config.L_cultivation_level
            }
        end
    end

    CONFIG_CACHE.exps = exps
    logger.info("Loaded %d exp configs", count_pairs(exps))
    return true
end

-- 加载伙伴星级配置
function M.load_companion_star_configs()
    local data = config_loader.get_config("Dfw_companion_star")
    if not data then
        return false
    end

    local stars = {}
    for id, config in pairs(data) do
        local star_id = tonumber(config.Star_id) or 0
        local level = tonumber(config.Level) or 0
        if star_id > 0 and level >= 0 then
            -- 使用 star_id_level 作为键
            local key = string.format("%d_%d", star_id, level)
            stars[key] = {
                id = tonumber(config.Id) or 0,
                star_id = star_id,
                level = level,
                attrs = config.Attr or {},
                consume = config.Consume or {}
            }
        end
    end

    CONFIG_CACHE.companion_stars = stars
    logger.info("Loaded %d companion star configs", count_pairs(stars))
    return stars
end

-- 加载大富翁格子数据配置
function M.load_cell_data_config()
    local data = config_loader.get_config("Dfw_cell_data")
    if not data then
        return false
    end

    -- 转换配置格式为二维数组 [map_id][cell_id]
    for cell_id, cell_data in pairs(data) do
        cell_id = tonumber(cell_id)
        if cell_id then
            local map_id = tonumber(cell_data.Map_id) or 1
            -- 确保map_id对应的表存在
            if not CONFIG_CACHE.cell_data[map_id] then
                CONFIG_CACHE.cell_data[map_id] = {}
            end
            
            -- 存储格子数据
            CONFIG_CACHE.cell_data[map_id][cell_data.Cell_id] = {
                id = cell_id,
                map_id = map_id,
                cell = tonumber(cell_data.Cell) or 0,
                cell_icon = tonumber(cell_data.Cell_icon) or 0,
                cell_id = tonumber(cell_data.Cell_id) or 0,
                cell_land = tonumber(cell_data.Cell_land) or 0,
                land_buy = tonumber(cell_data.Land_buy) or 0,
                land_unit = tonumber(cell_data.Land_unit) or 0,
                cell_events1 = cell_data.Cell_events1 or {},
                cell_events2 = cell_data.Cell_events2 or {},
                cell_events3 = cell_data.Cell_events3 or {}
            }
        end
    end

    logger.info("Cell data config loaded: %d maps", count_pairs(CONFIG_CACHE.cell_data))
    for map_id, cells in pairs(CONFIG_CACHE.cell_data) do
        logger.info("Map %d has %d cells", map_id, count_pairs(cells))
    end
    return true
end

-- 加载大富翁格子事件配置
function M.load_cell_events_config()
    local data = config_loader.get_config("Dfw_cell_events")
    if not data then
        return false
    end

    -- 转换配置格式
    for id, event_data in pairs(data) do
        local event_id = tonumber(event_data.Event_id)
        if event_id then
            CONFIG_CACHE.cell_events[event_id] = {
                id = tonumber(event_data.Id),
                event_id = event_id,
                event_type_id = tonumber(event_data.Event_type_id),
                resource = event_data.resource,
                activate = tonumber(event_data.Activate) or enum.CellEventActivateType.ACTIVATE_TYPE_MANUAL  -- 添加Activate字段，默认为调用主动
            }
        end
    end

    logger.info("Cell events config loaded: %d events", count_pairs(CONFIG_CACHE.cell_events))
    return true
end

-- 加载大富翁章节配置
function M.load_monopoly_config()
    local data = config_loader.get_config("Dfw_monopoly")
    if not data then
        return false
    end

    -- 转换配置格式
    for chapter_id, chapter_data in pairs(data) do
        chapter_id = tonumber(chapter_id)
        if chapter_id then
            -- 构建章节配置
            local chapter_config = {
                id = chapter_id,
                map_id = tonumber(chapter_data.Customs) or 1,
                bg_pic = chapter_data.Bg_pic,
                l_drama = chapter_data.L_drama,
                l_name = chapter_data.L_name,
                l_name_explain = chapter_data.L_name_explain,
                reward = chapter_data.Reward or {},
                unlock = tonumber(chapter_data.Unlock) or 0,
                victory_condition = chapter_data.Victory_condition or {}
            }

            -- 尝试加载地图配置
            local map_config = config_loader.get_config(string.format("amap%d", chapter_config.map_id))
            if map_config and map_config.tileMap then
                -- 转换tileMap格式
                local tile_map = {}
                for tile_id, tile_data in pairs(map_config.tileMap) do
                    -- 确保tile_id是数字
                    local numeric_id = tonumber(tile_id)
                    if numeric_id then
                        -- 确保nextIds是数字数组
                        local next_ids = {}
                        if tile_data.nextIds then
                            for _, next_id in ipairs(tile_data.nextIds) do
                                table.insert(next_ids, tonumber(next_id))
                            end
                        end
                        
                        tile_map[numeric_id] = {
                            id = numeric_id,
                            next_ids = next_ids
                        }
                    end
                end
                chapter_config.tile_map = tile_map
                logger.info("Loaded tile map for chapter %d, map_id: %d, tiles: %d", 
                    chapter_id, chapter_config.map_id, count_pairs(tile_map))
                logger.debug("Tile map for chapter %d: %s", chapter_id, utils.table_to_string(tile_map))
            else
                logger.info("No map config found for chapter %d, map_id: %d", 
                    chapter_id, chapter_config.map_id)
            end

            CONFIG_CACHE.monopoly[chapter_id] = chapter_config
        end
    end

    logger.info("Monopoly config loaded: %d chapters", count_pairs(CONFIG_CACHE.monopoly))
    return true
end

-- 加载大富翁随机事件配置
function M.load_cell_random_events_config()
    local data = config_loader.get_config("Dfw_cell_random")
    if not data then
        return false
    end

    -- 转换配置格式
    for id, random_event_data in pairs(data) do
        local random_id = tonumber(random_event_data.Id)
        if random_id then
            CONFIG_CACHE.cell_random_events[random_id] = {
                id = random_id,
                cell_events = random_event_data.Cell_events or {},
                cell_id = tonumber(random_event_data.Cell_id) or 0,
                cells = random_event_data.Cells or {},
                map_id = tonumber(random_event_data.Map_id) or 0,
                max_gen = tonumber(random_event_data.Generate_max) or 1,  -- 最大生成数量
                mutex = tonumber(random_event_data.Mutex) or 0,           -- 互斥事件ID
                repeat_no = tonumber(random_event_data.Repeat_no) or 0,   -- 不重复
                weight = tonumber(random_event_data.Weights) or 100       -- 生成权重
            }
        end
    end

    logger.info("Cell random events config loaded: %d events", count_pairs(CONFIG_CACHE.cell_random_events))
    return true
end

-- 添加通用的get_config方法，用于提供给table_service调用
function M.get_config(config_name)
    if not config_name then
        logger.error("Config name is nil, config_name: %s", config_name)
        return nil
    end
    logger.info("get_config, config_name: %s", config_name)
    -- 首先查找CONFIG_CACHE中是否已有对应配置
    if config_name == "units" and next(CONFIG_CACHE.units) then
        return CONFIG_CACHE.units
    elseif config_name == "initial_items" and next(CONFIG_CACHE.initial_items) then
        return CONFIG_CACHE.initial_items
    elseif config_name == "items" and next(CONFIG_CACHE.items) then
        return CONFIG_CACHE.items
    elseif config_name == "properties" and next(CONFIG_CACHE.properties) then
        return CONFIG_CACHE.properties
    elseif config_name == "equips" and next(CONFIG_CACHE.equips) then
        return CONFIG_CACHE.equips
    elseif config_name == "equip_levels" and next(CONFIG_CACHE.equip_levels) then
        return CONFIG_CACHE.equip_levels
    elseif config_name == "equip_odds" and next(CONFIG_CACHE.equip_odds) then
        return CONFIG_CACHE.equip_odds
    elseif config_name == "experience" and next(CONFIG_CACHE.exps) then
        return CONFIG_CACHE.exps
    elseif config_name == "companion_stars" and next(CONFIG_CACHE.companion_stars) then
        return CONFIG_CACHE.companion_stars
    elseif config_name == "cell_data" and next(CONFIG_CACHE.cell_data) then
        return CONFIG_CACHE.cell_data
    elseif config_name == "cell_events" and next(CONFIG_CACHE.cell_events) then
        return CONFIG_CACHE.cell_events
    elseif config_name == "monopoly" and next(CONFIG_CACHE.monopoly) then
        return CONFIG_CACHE.monopoly
    elseif config_name == "cell_random_events" and next(CONFIG_CACHE.cell_random_events) then
        return CONFIG_CACHE.cell_random_events
    end
    
    return nil
end

return M