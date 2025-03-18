local skynet = require "skynet"
local logger = require "logger"
local partner_model = require "models.partner_model"
local partner_dao = require "dao.partner_dao"
local utils = require "utils"
local item_service = require "services.item_service"
local user_service = require "services.user_service"
local table_service = require "services.table_service"
local db_client = require "game.db_client"
local enum = require "enum"

local M = {}

-- 使用枚举代替硬编码的伙伴类型常量
local PARTNER_TYPE = enum.ItemType.ITEM_TYPE_PARTNER
local PARTNER_FRAGMENT_TYPE = enum.ItemType.ITEM_TYPE_PARTNER_FRAGMENT

-- 计算伙伴战力 - 简化版
local function calculate_power(partner)
    local power = 0
    
    -- 基础战力计算，只考虑等级、星级和品质
    power = 100 + partner.level * 10 + partner.star * 100 + (partner.quality or 1) * 200
    
    -- 如果有属性数据，简单累加
    if partner.properties then
        for _, prop in ipairs(partner.properties) do
            if prop.prop_id == enum.PropType.PROP_HP then
                power = power + prop.value * 0.1
            elseif prop.prop_id == enum.PropType.PROP_ATTACK then
                power = power + prop.value * 2.0
            elseif prop.prop_id == enum.PropType.PROP_DEFENSE then
                power = power + prop.value * 1.5
            end
        end
    end
    
    return math.floor(power)
end

-- 获取伙伴所需的属性 - 简化版
local function get_partner_properties(unit_id, level, star, quality)
    local properties = {}
    
    -- 获取单位配置
    local unit_config = table_service.get_unit_config(unit_id)
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return properties
    end
    
    -- 使用单位表中的基础属性，简单应用等级、星级倍率
    local level_multiplier = 1 + (level - 1) * 0.1  -- 每级提升10%
    local star_multiplier = 1 + (star - 1) * 0.1    -- 每星提升10%
    local quality_multiplier = 1 + (quality - 1) * 0.2  -- 每品质提升20%
    
    -- 基础属性 (HP, MP, 攻击, 防御, 速度)
    local base_props = {
        { id = enum.PropType.PROP_HP, value = unit_config.base_hp or 100 },  -- 生命值
        { id = enum.PropType.PROP_MP, value = unit_config.base_mp or 50 },   -- 魔法值
        { id = enum.PropType.PROP_ATTACK, value = unit_config.base_attack or 10 },  -- 攻击力
        { id = enum.PropType.PROP_DEFENSE, value = unit_config.base_defense or 5 },  -- 防御力
        { id = enum.PropType.PROP_SPEED, value = unit_config.base_speed or 100 }   -- 速度
    }
    
    -- 计算每个属性并添加到结果中
    for _, prop in ipairs(base_props) do
        -- 简化计算公式: 基础值 * 等级倍率 * 星级倍率 * 品质倍率
        local final_value = prop.value * level_multiplier * star_multiplier * quality_multiplier
        
        table.insert(properties, {
            prop_id = prop.id,
            value = math.floor(final_value),
            extra = 0
        })
    end
    
    -- 添加战斗属性 (命中率、闪避率、暴击率等)
    local combat_props = {
        { id = enum.PropType.PROP_HIT, value = unit_config.hit_rate or 5 },       -- 命中率
        { id = enum.PropType.PROP_DODGE, value = unit_config.dodge_rate or 3 },     -- 闪避率
        { id = enum.PropType.PROP_CRIT_RATE, value = unit_config.crit_rate or 5 },      -- 暴击率
        { id = enum.PropType.PROP_CRIT_DMG, value = unit_config.crit_dmg or 150 }      -- 暴击伤害
    }
    
    for _, prop in ipairs(combat_props) do
        -- 简化计算: 品质影响战斗属性
        local final_value = prop.value * (1 + (quality - 1) * 0.05)
        
        table.insert(properties, {
            prop_id = prop.id,
            value = math.floor(final_value),
            extra = 0
        })
    end
    
    return properties
end

-- 获取用户已解锁的伙伴
local function _get_unlocked_partners(user_id)
    if not user_id then
        return nil, "invalid user id"
    end
    
    -- 从DAO层获取伙伴
    local partners = partner_dao.get_user_partners(user_id)
    if not partners or #partners == 0 then
        return {}
    end
    
    return partners
end

-- 检查伙伴是否存在
local function _check_partner_exists(user_id, unit_id)
    local partners = _get_unlocked_partners(user_id)
    
    for _, partner in ipairs(partners) do
        if partner.unit_id == unit_id then
            return true, partner
        end
    end
    
    return false, nil
end

-- 根据ID获取伙伴
local function _get_partner_by_id(partner_id)
    return partner_dao.get_partner(partner_id)
end

-- 创建新伙伴
local function _create_partner(user_id, unit_id)
    -- 获取单位配置
    local unit_config = table_service.get_unit_config(unit_id)
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return nil
    end
    
    -- 创建伙伴数据
    local new_partner = partner_model.new({
        user_id = user_id,
        unit_id = unit_id,
        level = 1,
        exp = 0,
        star = 0,
        -- 从配置获取quality、race和forte字段的值，而不是存入数据库
        properties = get_partner_properties(unit_id, 1, 1, unit_config.quality or enum.Quality.QUALITY_WHITE)
    })
    
    -- 计算战力
    new_partner.power = calculate_power(new_partner)
    
    -- 保存伙伴数据
    local ok = partner_dao.create_partner(new_partner)
    if not ok then
        logger.error("Failed to create partner for user_id: %d, unit_id: %d", user_id, unit_id)
        return nil
    end
    
    logger.info("Created new partner for user_id: %d, unit_id: %d, partner_id: %d", 
        user_id, unit_id, new_partner.id)
    
    return new_partner
end

-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    logger.info("Getting partners for user_id: %d", user_id)
    
    local partners = {}
    
    -- 1. 从配置中获取所有单位配置（伙伴类型 Type=4）
    local unit_configs = table_service.get_unit_configs()
    if not unit_configs then
        logger.error("Failed to get unit configs")
        return nil
    end
    
    -- 记录所有伙伴类型的单位ID
    local all_partner_unit_ids = {}
    for unit_id, unit_config in pairs(unit_configs) do
        if unit_config.type == PARTNER_TYPE then
            all_partner_unit_ids[unit_id] = true
        end
    end
    
    -- 2. 从数据库获取已解锁的伙伴
    local unlocked_partners = _get_unlocked_partners(user_id)
    if not unlocked_partners then
        logger.error("Failed to get unlocked partners for user_id: %d", user_id)
        return nil
    end
    logger.info("unlocked_partners: %s", utils.table_to_string(unlocked_partners))
    
    -- 获取伙伴碎片信息
    local fragments = item_service.get_user_items_by_type(user_id, PARTNER_FRAGMENT_TYPE)
    local fragment_map = {}
    for _, fragment in ipairs(fragments or {}) do
        fragment_map[fragment.item_id] = fragment.count
    end
    
    -- 记录已解锁的伙伴ID和信息
    local unlocked_map = {}
    for _, partner in ipairs(unlocked_partners) do
        unlocked_map[partner.unit_id] = partner
        logger.info("Added unlocked partner to map: unit_id=%d", partner.unit_id)
    end
    
    logger.info("unlocked_map: %s", utils.table_to_string(unlocked_map))
    -- 3. 处理所有伙伴（包括已解锁和未解锁的）
    for unit_id in pairs(all_partner_unit_ids) do
        local unit_config = table_service.get_unit_config(unit_id)
        if not unit_config then
            logger.error("Failed to get unit config for unit_id: %d", unit_id)
            goto continue
        end
        
        -- 从配置中获取解锁所需的碎片信息
        local fragment_need = 0
        local fragment_id = 0
        if unit_config.shards and type(unit_config.shards) == "table" and #unit_config.shards >= 2 then
            -- 碎片配置格式: {物品ID, 数量}
            fragment_need = unit_config.shards[2]
            fragment_id = unit_config.shards[1]
        else
            fragment_need = unit_config.unlock_fragments or table_service.get_default_unlock_fragments()
        end
        local partner = unlocked_map[unit_id]
        logger.info("Checking partner: unit_id=%d, is_unlocked=%s", unit_id, partner ~= nil)
        
        local partner_info
        
        if partner then
            -- 已解锁的伙伴
            logger.info("Processing unlocked partner: unit_id=%d", unit_id)
            local max_level = table_service.get_max_partner_level()
            local max_star = table_service.get_max_partner_star(unit_config.star_id)
            logger.info("max_star for unit_id=%d, star_id=%d: %d", unit_id, unit_config.star_id, max_star)
            
            -- 确保 level 和 star 是数字类型
            local partner_level = tonumber(partner.level) or 1
            local partner_star = tonumber(partner.star) or 0
            logger.info("partner_star=%d, max_star=%d for unit_id=%d", partner_star, max_star, unit_id)
            
            local can_level_up = partner_level < max_level
            local can_star_up = partner_star < max_star
            logger.info("can_star_up=%s for unit_id=%d", tostring(can_star_up), unit_id)
            
            -- 获取升级和升星消耗
            local level_up_cost = {}
            local star_up_cost = {}
            
            if can_level_up then
                level_up_cost = table_service.get_partner_level_up_cost(partner.unit_id, partner_level)
            end
            
            if can_star_up then
                star_up_cost = table_service.get_partner_star_up_cost(partner.unit_id, partner_star)
            end
            
            -- 确保已解锁的伙伴状态为 PARTNER_STATE_UNLOCKED (2)
            local state = enum.PartnerState.PARTNER_STATE_UNLOCKED
            logger.info("Setting unlocked partner state: unit_id=%d, state=%d", unit_id, state)
            
            partner_info = {
                base_info = {
                    partner_id = partner.id,
                    unit_id = partner.unit_id,
                    level = partner_level,
                    exp = partner.exp,
                    quality = unit_config.quality or enum.Quality.QUALITY_WHITE,
                    star = partner_star,
                    create_time = partner.create_time,
                    race = unit_config.race or 0,
                    forte = unit_config.forte or 0
                },
                state = state,
                fragment_count = fragment_map[unit_id] or 0,
                fragment_need = fragment_need,
                can_level_up = can_level_up,
                can_star_up = can_star_up,
                level_up_cost = level_up_cost,
                star_up_cost = star_up_cost
            }
            logger.info("Created partner_info: unit_id=%d, state=%d, can_star_up=%s", 
                unit_id, partner_info.state, tostring(partner_info.can_star_up))
        else
            -- 未解锁的伙伴
            logger.info("Processing locked partner: unit_id=%d", unit_id)
            local fragment_count = fragment_map[fragment_id] or 0
            local state = enum.PartnerState.PARTNER_STATE_LOCKED -- 默认为未解锁状态 (3)
            
            -- 如果碎片足够但未解锁，设为可解锁状态
            if fragment_count >= fragment_need then
                state = enum.PartnerState.PARTNER_STATE_AVAILABLE -- 可解锁状态 (1)
            end
            
            logger.info("Setting locked partner state: unit_id=%d, state=%d, fragment_count=%d, fragment_need=%d", 
                unit_id, state, fragment_count, fragment_need)
            
            partner_info = {
                base_info = {
                    partner_id = 0, -- 未解锁
                    unit_id = unit_id,
                    level = 1,
                    exp = 0,
                    quality = unit_config.quality or enum.Quality.QUALITY_WHITE,
                    star = 0,
                    create_time = 0,
                    race = unit_config.race or 0,
                    forte = unit_config.forte or 0
                },
                state = state,
                fragment_count = fragment_count,
                fragment_need = fragment_need,
                can_level_up = false,
                can_star_up = false,
                level_up_cost = {},
                star_up_cost = {}
            }
            logger.info("Created partner_info with state: unit_id=%d, state=%d", unit_id, partner_info.state)
        end
        
        table.insert(partners, partner_info)
        
        ::continue::
    end
    
    -- 排序: 已解锁 > 可解锁 > 未解锁，同状态下按战力、品质、星级排序
    table.sort(partners, function(a, b)
        if a.state ~= b.state then
            return a.state < b.state -- 状态数字越小优先级越高
        end
        
        if a.base_info.quality ~= b.base_info.quality then
            return a.base_info.quality > b.base_info.quality -- 品质高的排前面
        end
        
        if a.base_info.star ~= b.base_info.star then
            return a.base_info.star > b.base_info.star -- 星级高的排前面
        end
        
        return a.base_info.unit_id < b.base_info.unit_id -- 最后按ID排序
    end)
    
    return partners
end

-- 伙伴升级
function M.level_up_partner(user_id, partner_id)
    -- 确保 partner_id 是数字类型
    partner_id = tonumber(partner_id)
    logger.info("Level up partner for user_id: %d, partner_id: %d", user_id, partner_id or 0)
    
    -- 检查 partner_id 的有效性
    if not partner_id or partner_id <= 0 then
        logger.error("Invalid partner_id: %d", partner_id or 0)
        return false, "invalid_partner_id"
    end
    
    -- 获取伙伴信息
    local partner = _get_partner_by_id(partner_id)
    if not partner or partner.user_id ~= user_id then
        logger.error("Partner not found or user mismatch: user_id=%d, partner_id=%d", user_id, partner_id)
        return false
    end
    
    -- 检查等级上限
    local max_level = table_service.get_max_partner_level()
    if tonumber(partner.level) >= max_level then
        logger.error("Partner already at max level: %d", max_level)
        return false
    end
    
    -- 获取单位配置
    local unit_config = table_service.get_unit_config(partner.unit_id)
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", partner.unit_id)
        return false
    end
    
    -- 获取升级消耗
    local level_up_cost = table_service.get_partner_level_up_cost(partner.unit_id, partner.level)
    if not level_up_cost or #level_up_cost == 0 then
        logger.error("Failed to get level up cost for partner_id: %d", partner_id)
        return false
    end
    
    -- 检查道具是否足够
    local has_enough, items_info = item_service.check_items_enough(user_id, level_up_cost)
    if not has_enough then
        logger.error("Not enough items for level up partner_id: %d", partner_id)
        return false
    end
    
    -- 扣除物品
    local consume_result, consumed_items = item_service.consume_items(user_id, level_up_cost)
    if not consume_result then
        logger.error("Failed to consume items for level up partner_id: %d", partner_id)
        return false
    end
    
    -- 升级伙伴
    local old_level = partner.level
    partner.level = partner.level + 1
    partner.exp = 0
    
    -- 更新伙伴信息
    local update_result = partner_dao.update_partner(partner)
    if not update_result then
        logger.error("Failed to update partner for level up: partner_id=%d", partner_id)
        return false
    end
    
    -- 记录伙伴变化
    db_client.log_partner_change(user_id, partner_id, old_level, partner.level, "LEVEL_UP", os.time(), utils.table_to_string(consumed_items))
    
    -- 构造返回的伙伴信息
    local updated_partner = {
        base_info = {
            partner_id = partner.id,
            unit_id = partner.unit_id,
            level = partner.level,
            exp = partner.exp,
            quality = partner.quality,
            star = partner.star,
            create_time = partner.create_time,
            race = partner.race,
            forte = partner.forte,
            properties = partner.properties
        },
        state = enum.PartnerState.PARTNER_STATE_UNLOCKED, -- 已解锁
        fragment_count = 0,
        fragment_need = 0,
        can_level_up = partner.level < max_level,
        can_star_up = partner.star < table_service.get_max_partner_star(unit_config.star_id),
        level_up_cost = partner.level < max_level and 
                        table_service.get_partner_level_up_cost(partner.unit_id, partner.level) or {},
        star_up_cost = partner.star < table_service.get_max_partner_star(unit_config.star_id) and 
                      table_service.get_partner_star_up_cost(partner.unit_id, partner.star) or {}
    }
    
    return true, updated_partner, property_changes, consumed_items
end

-- 伙伴升星
function M.star_up_partner(user_id, partner_id)
    -- 确保 partner_id 是数字类型
    partner_id = tonumber(partner_id)
    logger.info("Star up partner for user_id: %d, partner_id: %d", user_id, partner_id or 0)
    
    -- 检查 partner_id 的有效性
    if not partner_id or partner_id <= 0 then
        logger.error("Invalid partner_id: %d", partner_id or 0)
        return false, "invalid_partner_id"
    end
    
    -- 获取伙伴信息
    local partner = _get_partner_by_id(partner_id)
    if not partner or partner.user_id ~= user_id then
        logger.error("Partner not found or user mismatch: user_id=%d, partner_id=%d", user_id, partner_id)
        return false
    end
    
    -- 获取单位配置
    local unit_config = table_service.get_unit_config(tonumber(partner.unit_id))
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", partner.unit_id)
        return false
    end
    
    -- 检查星级上限
    local max_star = table_service.get_max_partner_star(unit_config.star_id)
    if tonumber(partner.star) >= max_star then
        logger.error("Partner already at max star: %d", max_star)
        return false
    end
    
    -- 获取升星消耗
    local star_up_cost = table_service.get_partner_star_up_cost(partner.unit_id, partner.star)
    if not star_up_cost or #star_up_cost == 0 then
        logger.error("Failed to get star up cost for partner_id: %d", partner_id)
        return false
    end
    
    -- 检查道具是否足够
    local has_enough, items_info = item_service.check_items_enough(user_id, star_up_cost)
    if not has_enough then
        logger.error("Not enough items for star up partner_id: %d", partner_id)
        return false
    end
    
    -- 扣除物品
    local consume_result, consumed_items = item_service.consume_items(user_id, star_up_cost)
    if not consume_result then
        logger.error("Failed to consume items for star up partner_id: %d", partner_id)
        return false
    end
    
    -- 升星伙伴
    local old_star = partner.star
    partner.star = partner.star + 1
    
    -- 重新计算战力
    partner.power = calculate_power(partner)
    
    -- 更新伙伴信息
    local update_result = partner_dao.update_partner(partner)
    if not update_result then
        logger.error("Failed to update partner for star up: partner_id=%d", partner_id)
        return false
    end
    
    -- 记录伙伴变化
    db_client.log_partner_change(user_id, partner_id, old_star, partner.star, "STAR_UP", os.time(), utils.table_to_string(consumed_items))
    
    -- 构造返回的伙伴信息
    local updated_partner = {
        base_info = {
            partner_id = partner.id,
            unit_id = partner.unit_id,
            level = partner.level,
            exp = partner.exp,
            quality = partner.quality,
            star = partner.star,
            create_time = partner.create_time,
            race = partner.race,
            forte = partner.forte,
            properties = partner.properties
        },
        state = enum.PartnerState.PARTNER_STATE_UNLOCKED, -- 已解锁
        fragment_count = 0,
        fragment_need = 0,
        can_level_up = partner.level < table_service.get_max_partner_level(),
        can_star_up = partner.star < max_star,
        level_up_cost = partner.level < table_service.get_max_partner_level() and 
                        table_service.get_partner_level_up_cost(partner.unit_id, partner.level) or {},
        star_up_cost = partner.star < max_star and 
                      table_service.get_partner_star_up_cost(partner.unit_id, partner.star) or {}
    }
    
    return true, updated_partner, property_changes, consumed_items
end

-- 伙伴解锁
function M.unlock_partner(user_id, unit_id)
    logger.info("Unlock partner for user_id: %d, unit_id: %d", user_id, unit_id)
    
    -- 检查伙伴是否已解锁
    local exists, existing_partner = _check_partner_exists(user_id, unit_id)
    if exists then
        logger.error("Partner already unlocked: user_id=%d, unit_id=%d", user_id, unit_id)
        return false
    end
    
    -- 获取单位配置
    local unit_config = table_service.get_unit_config(unit_id)
    if not unit_config then
        logger.error("Failed to get unit config for unit_id: %d", unit_id)
        return false
    end
    
    -- 检查是否是伙伴类型
    if unit_config.type ~= PARTNER_TYPE then
        logger.error("Unit is not partner type: unit_id=%d, type=%d", unit_id, unit_config.type)
        return false
    end
    
    -- 从unit配置中获取碎片信息
    if not unit_config.shards or type(unit_config.shards) ~= "table" or #unit_config.shards < 2 then
        logger.error("Invalid shards configuration for unit_id: %d", unit_id)
        return false
    end
    
    -- 获取碎片ID和所需数量
    local fragment_item_id = unit_config.shards[1]
    local fragment_need = unit_config.shards[2]
    
    logger.debug("Unlocking partner - unit_id: %d, fragment_id: %d, need_count: %d", 
        unit_id, fragment_item_id, fragment_need)
    
    -- 获取玩家拥有的该伙伴碎片
    local items = item_service.get_user_items_by_type(user_id, enum.ItemType.ITEM_TYPE_PARTNER_FRAGMENT)
    local fragment_count = 0
    logger.info("items: %s", utils.table_to_string(items))
    -- 查找指定的碎片
    for _, item in ipairs(items or {}) do
        if item.item_id == fragment_item_id then
            fragment_count = item.count
            break
        end
    end
    
    -- 检查碎片是否足够
    if fragment_count < fragment_need then
        logger.error("Not enough fragments to unlock partner: need=%d, have=%d", fragment_need, fragment_count)
        return false
    end
    
    -- 扣除碎片
    local consume_result = item_service.consume_item(user_id, fragment_item_id, fragment_need, enum.ChangeSource.SOURCE_UNLOCK_PARTNER)
    if not consume_result then
        logger.error("Failed to consume fragments for unlock partner: unit_id=%d, fragment_id=%d", unit_id, fragment_item_id)
        return false
    end
    
    -- 创建伙伴
    local new_partner = _create_partner(user_id, unit_id)
    if not new_partner then
        logger.error("Failed to create partner: user_id=%d, unit_id=%d", user_id, unit_id)
        return false
    end
    
    -- 记录伙伴变化
    db_client.log_partner_change(user_id, new_partner.id, unit_id, fragment_need, "UNLOCK", os.time())
    
    -- 获取伙伴的最新碎片数量
    local items = item_service.get_user_items_by_type(user_id, enum.ItemType.ITEM_TYPE_PARTNER_FRAGMENT)
    local updated_fragment_count = 0
    for _, item in ipairs(items or {}) do
        if item.item_id == fragment_item_id then
            updated_fragment_count = item.count
            break
        end
    end
    
    -- 构造返回的伙伴信息
    local unlocked_partner = {
        base_info = {
            partner_id = new_partner.id,
            unit_id = new_partner.unit_id,
            level = new_partner.level,
            exp = new_partner.exp,
            quality = new_partner.quality,
            star = new_partner.star,
            create_time = new_partner.create_time,
            race = new_partner.race,
            forte = new_partner.forte,
            properties = new_partner.properties
        },
        state = enum.PartnerState.PARTNER_STATE_UNLOCKED, -- 已解锁
        fragment_count = updated_fragment_count,
        fragment_need = 0,
        can_level_up = true,
        can_star_up = new_partner.star < table_service.get_max_partner_star(unit_config.star_id),
        level_up_cost = table_service.get_partner_level_up_cost(unit_id, 1),
        star_up_cost = table_service.get_partner_star_up_cost(unit_id, 1)
    }
    
    -- 返回消耗的碎片数量
    return true, unlocked_partner, fragment_need
end

return M 