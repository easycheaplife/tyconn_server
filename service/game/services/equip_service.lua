local skynet = require "skynet"
local logger = require "logger"
local bag_dao = require "dao.bag_dao"
local item_dao = require "dao.item_dao"
local enum = require "game.define.enum"
local cjson = require "cjson"
local snowflake = require "utils.snowflake"
local equipment_dao = require "dao.equipment_dao"
local property_service = require "services.property_service"
local config_service = require "services.config_service"

local M = {}

-- 在函数内导入时使用局部变量缓存结果
local item_service_cache
local function get_item_service()
    if not item_service_cache then
        item_service_cache = require "services.item_service"
    end
    return item_service_cache
end

-- 检查物品是否可装备
function M.check_can_equip(user_id, from_bag, from_slot, equip_slot)
    -- 1. 获取物品信息
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 2. 查找物品
    local item = nil
    for _, it in ipairs(items) do
        if it.bag_type == from_bag and it.slot_index == from_slot then
            item = it
            break
        end
    end
    
    if not item then
        return false, "item not found"
    end
    
    -- 3. 检查物品类型
    local config = config_service.get_item_config(item.item_id)
    if not config or config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    
    -- 4. 检查装备位置
    if config.equip_slot ~= equip_slot then
        return false, "equip slot not match"
    end
    
    -- 5. 检查等级限制
    local user_service = require("services.user_service")
    if config.level_required then
        local user_level = user_service.get_user_level(user_id)
        if user_level < config.level_required then
            return false, "level not enough"
        end
    end
    
    return true, nil, item
end

-- 装备物品
function M.equip_item(user_id, from_bag, from_slot, equip_slot)
    logger.info("equip_item user_id: %d, from_bag: %d, from_slot: %d, equip_slot: %d", user_id, from_bag, from_slot, equip_slot)
    -- 1. 检查是否可装备
    local ok, err, from_item = M.check_can_equip(user_id, from_bag, from_slot, equip_slot)
    if not ok then
        return false, err
    end
    
    logger.info("equip_item ok")
    -- 2. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    logger.info("equip_item items ok")
    -- 3. 查找当前已装备在该槽位的物品(如果有)
    local curr_equip = nil
    for _, item in ipairs(items) do
        -- 检查是否已经有物品装备在这个槽位上
        -- 装备状态通过equip_slot属性记录
        if item.equip_slot and item.equip_slot == equip_slot then
            curr_equip = item
            break
        end
    end
    logger.info("equip_item curr_equip ok")
    -- 4. 更新物品装备状态
    -- 4.1 更新要装备的物品
    from_item.equip_slot = equip_slot  -- 设置装备槽位
    from_item.is_equipped = true       -- 标记为已装备
    
    -- 4.2 如果有当前装备，取消其装备状态
    if curr_equip then
        curr_equip.equip_slot = nil    -- 清除装备槽位
        curr_equip.is_equipped = false -- 标记为未装备
    end
    logger.info("equip_item curr_equip ok")
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 6. 更新角色属性
    property_service.recalc_equip_props(user_id)
    
    -- 7. 触发装备事件
    skynet.send(".event", "lua", "trigger_event", "on_equip_changed", {
        user_id = user_id,
        equip_id = from_item.id,
        slot = equip_slot,
        action = "equip"    
    })
    logger.info("equip_item trigger_event ok")
    -- 8. 计算战力变化
    local config_service = require "services.config_service"
    local power_change = 0
    
    -- 获取新装备提供的战力
    local from_config = config_service.get_equipment_config(from_item.item_id)
    if from_config and from_config.power then
        power_change = power_change + from_config.power
    end
    
    -- 减去旧装备的战力(如果有)
    if curr_equip then
        local curr_config = config_service.get_equipment_config(curr_equip.item_id)
        if curr_config and curr_config.power then
            power_change = power_change - curr_config.power
        end
    end
    
    return true, nil, from_item, curr_equip, power_change
end

-- 卸下装备
function M.unequip_item(user_id, equip_slot)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "get items failed"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.equip_slot and item.equip_slot == equip_slot then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "equipment not found"
    end
    
    -- 3. 清除装备状态
    equip.equip_slot = nil    -- 清除装备槽位
    equip.is_equipped = false -- 标记为未装备
    
    -- 4. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "save item failed"
    end
    
    -- 5. 更新角色属性
    property_service.recalc_equip_props(user_id)
    
    -- 6. 触发装备事件
    skynet.send(".event", "lua", "trigger_event", "on_equip_changed", {
        user_id = user_id,
        equip_id = equip.id,
        slot = equip_slot,
        action = "unequip"
    })
    
    -- 7. 计算战力变化
    local config_service = require "services.config_service"
    local power_change = 0
    
    -- 减去卸下装备的战力
    local equip_config = config_service.get_equipment_config(equip.item_id)
    if equip_config and equip_config.power then
        power_change = -equip_config.power
    end
    
    return true, nil, equip, power_change
end

-- 移动装备(处理装备栏相关的移动)
function M.move_equipment(user_id, from_bag, from_slot, to_bag, to_slot)
    if from_bag == enum.BagType.BAG_TYPE_EQUIP then
        -- 从装备栏卸下
        return M.unequip_item(user_id, from_slot)
    elseif to_bag == enum.BagType.BAG_TYPE_EQUIP then
        -- 装备到装备栏
        return M.equip_item(user_id, from_bag, from_slot, to_slot)
    else
        -- 普通物品移动，使用背包服务处理
        local bag_service = require("services.bag_service")
        return bag_service.move_item(user_id, from_bag, from_slot, to_bag, to_slot)
    end
end

-- 获取已装备物品列表
function M.get_equipments(user_id)
    local items = item_dao.get_user_items(user_id)
    if not items then
        return {}
    end
    
    local equipments = {}
    for _, item in ipairs(items) do
        -- 检查物品是否已装备
        if item.is_equipped and item.equip_slot then
            -- 以装备槽位为索引存储装备
            equipments[item.equip_slot] = item
        end
    end
    
    return equipments
end

-- 获取装备提供的战斗力
function M.get_equipment_power(user_id)
    local equipments = M.get_equipments(user_id)
    if not equipments then
        return 0
    end
    
    local total_power = 0
    local config_service = require "services.config_service"
    
    for _, equip in pairs(equipments) do
        local item_config = config_service.get_equipment_config(equip.item_id)
        if item_config and item_config.power then
            total_power = total_power + item_config.power
        end
    end
    
    return total_power
end

-- 检查装备是否已过期
function M.check_equipment_expire(user_id)
    local item_dao = require "dao.item_dao"
    local items = item_dao.get_user_items(user_id)
    if not items then
        return {}
    end
    
    local now = os.time()
    local expired_items = {}
    local need_update = false
    
    for i, item in ipairs(items) do
        -- 检查是否是已装备且已过期的物品
        if item.is_equipped and item.expire_time and item.expire_time > 0 and item.expire_time <= now then
            -- 记录过期物品
            table.insert(expired_items, table.clone(item))
            
            -- 清除装备状态
            item.is_equipped = false
            item.equip_slot = nil
            need_update = true
        end
    end
    
    -- 如果有过期装备，更新数据库
    if need_update then
        item_dao.update_user_items(user_id, items)
    end
    
    -- 如果有过期装备，重新计算战力
    if #expired_items > 0 then
        property_service.recalc_equip_props(user_id)
    end
    
    return expired_items
end

-- 获取装备概率等级
function M.get_user_equip_odds_level(user_id)
    local equipment_dao = require "dao.equipment_dao"
    local level_data = equipment_dao.get_user_equip_level(user_id)
    if not level_data then
        return 1  -- 默认等级
    end
    return level_data.level
end

-- 获取用户装备等级是否在升级中
function M.is_user_equip_level_upgrading(user_id)
    local redis = require "db.redis_client"
    local key = "user:" .. user_id .. ":equip_level_upgrading"
    
    local expire_time = redis.get(key)
    if not expire_time then
        return false, 0, 0
    end
    
    local now = os.time()
    local remaining = tonumber(expire_time) - now
    
    if remaining <= 0 then
        -- 升级已完成，删除键并升级等级
        redis.del(key)
        M.complete_equip_level_upgrade(user_id)
        return false, 0, 0
    end
    
    -- 返回正在升级，剩余时间，结束时间
    return true, remaining, tonumber(expire_time)
end

-- 开始升级装备等级
function M.start_upgrade_equip_odds_level(user_id, item_id, item_count)
    if not user_id then
        return false, "invalid user_id"
    end
    
    -- 获取当前装备等级信息
    local level_info = equipment_dao.get_equip_level_info(user_id)
    if not level_info then
        logger.error("Failed to get equipment level info for user %d", user_id)
        return false, "failed to get equipment level info"
    end
    
    -- 检查是否已在升级中
    if level_info.is_upgrading then
        return false, "already upgrading"
    end
    
    -- 获取下一等级配置
    local next_level = level_info.current_level + 1
    local next_level_config = config_service.get_equipment_level_config(next_level)
    
    if not next_level_config then
        logger.error("No configuration found for equipment level %d", next_level)
        return false, "max level reached"
    end
    
    -- 检查道具要求
    local required_item_id = next_level_config.item_id or item_id
    local required_count = next_level_config.item_count or item_count
    
    -- 检查道具数量
    local item_service = get_item_service()
    if not item_service.consume_item(user_id, required_item_id, required_count) then
        logger.warn("Not enough items for user %d to upgrade equipment level", user_id)
        return false, "not enough items"
    end
    
    -- 设置升级开始和结束时间
    local now = os.time()
    local upgrade_time = next_level_config.upgrade_time or 60  -- 默认60秒
    local end_time = now + upgrade_time
    
    -- 开始升级
    if not equipment_dao.start_equip_level_upgrade(user_id, now, end_time) then
        -- 升级失败，返还物品
        item_service.add_item(user_id, required_item_id, required_count)
        logger.error("Failed to start equipment level upgrade for user %d", user_id)
        return false, "upgrade failed"
    end
    
    -- 触发升级开始事件
    skynet.send(".event", "lua", "trigger_event", "on_equip_level_upgrade_started", {
        user_id = user_id,
        from_level = level_info.current_level,
        to_level = next_level,
        start_time = now,
        end_time = end_time
    })
    
    logger.info("User %d started equipment level upgrade from %d to %d",
                user_id, level_info.current_level, next_level)
    
    -- 返回升级信息
    return true, {
        current_level = level_info.current_level,
        next_level = next_level,
        upgrade_time = upgrade_time,
        start_time = now,
        end_time = end_time
    }
end

-- 加速装备等级升级
function M.speedup_equip_level_upgrade(user_id, use_ad, use_item, speedup_item_id)
    -- 检查是否在升级中
    local is_upgrading, remaining, expire_time = M.is_user_equip_level_upgrading(user_id)
    if not is_upgrading then
        return false, "not upgrading"
    end
    
    local reduction_time = 0
    
    -- 广告加速
    if use_ad then
        -- 获取广告加速配置
        local ad_speedup = config_service.get_config_value("equip_level_ad_speedup") or 300
        reduction_time = reduction_time + ad_speedup
    end
    
    -- 道具加速
    if use_item and speedup_item_id then
        -- 获取道具加速配置
        local item_speedup = config_service.get_config_value("equip_level_item_speedup_" .. speedup_item_id) or 600
        
        -- 消耗道具
        local item_service = get_item_service()
        local ok, err = item_service.consume_item(user_id, speedup_item_id, 1)
        if not ok then
            return false, err or "not enough items"
        end
        
        reduction_time = reduction_time + item_speedup
    end
    
    -- 更新升级时间
    if reduction_time > 0 then
        local redis = require "db.redis_client"
        local key = "user:" .. user_id .. ":equip_level_upgrading"
        
        local new_expire_time = math.max(os.time() + 1, expire_time - reduction_time)
        local new_remaining = new_expire_time - os.time()
        
        redis.set(key, new_expire_time)
        redis.expire(key, new_remaining + 60)  -- 额外60秒确保过期
        
        return true, nil, new_remaining, new_expire_time
    end
    
    return true, nil, remaining, expire_time
end

-- 根据权重随机选择品质
local function random_quality_by_weights(weights)
    local total_weight = 0
    for quality, weight in pairs(weights) do
        total_weight = total_weight + weight
    end
    
    local rand = math.random(1, total_weight)
    local current_weight = 0
    
    for quality = 1, 9 do
        local weight = weights[quality] or 0
        current_weight = current_weight + weight
        if rand <= current_weight then
            return quality
        end
    end
    
    return 1  -- 默认品质
end

-- 生成随机装备属性
local function generate_random_attributes(equip_level, quality, equip_config)
    local config_service = require "services.config_service"
    local level_config = config_service.get_equipment_level_config(equip_level)
    if not level_config then
        return {}
    end
    
    -- 获取对应品质的属性配置
    local qua_key = "qua_" .. quality
    local attr_config = level_config[qua_key]
    if not attr_config or #attr_config == 0 then
        return {}
    end
    
    -- 确定属性数量
    local attr_num = equip_config.attr_num[quality] or 1
    
    -- 随机生成属性
    local attributes = {}
    for i = 1, attr_num do
        -- 随机选择一个属性配置
        local rand_index = math.random(1, #attr_config)
        local attr_def = attr_config[rand_index]
        
        -- 属性定义格式: [属性ID, 值类型, 最小值, 最大值]
        local attr_id = attr_def[1]
        local value_type = attr_def[2]
        local min_value = attr_def[3]
        local max_value = attr_def[4]
        
        -- 生成随机值
        local value = math.random(min_value, max_value)
        
        -- 添加到属性列表
        attributes[attr_id] = value
    end
    
    return attributes
end

-- 随机获取装备
function M.random_equipment(user_id, part)
    if not user_id then
        return nil, "invalid user id"
    end
    
    -- 获取装备配置
    local base_config = config_service.get_equip_base_config()
    if not base_config then
        logger.error("Failed to get equip base config")
        return nil, "config error"
    end
    
    -- 如果没有指定部位，随机选择
    local target_part = part or 0
    if target_part <= 0 or target_part > 6 then
        local idx = math.random(1, #base_config.parts)
        target_part = base_config.parts[idx]
    end
    
    -- 获取装备模板
    local template = config_service.get_random_equip_template(target_part)
    if not template then
        logger.error("Failed to get equip template for part %d", target_part)
        return nil, "template error"
    end
    
    -- 随机品质
    local quality_odds = base_config.quality_odds
    local rnd = math.random(1, 100)
    local quality = 1
    local sum = 0
    
    for i, odds in ipairs(quality_odds) do
        sum = sum + odds
        if rnd <= sum then
            quality = i
            break
        end
    end
    
    -- 创建装备
    local item_id = template.item_id_base + quality - 1
    local equip = {
        id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
        user_id = user_id,
        item_id = item_id,
        count = 1,
        bag_type = enum.BagType.EQUIPMENT,
        slot_index = 0, -- 临时
        bind_type = enum.BindType.BIND_NONE,
        acquire_time = os.time(),
        expire_time = 0,
        quality = quality,
        level = 1,
        enhance_level = 0,
        refine_level = 0,
        gem_slots = {},
        is_equipped = false,
        equip_slot = nil,
        props = {}
    }
    
    -- 生成属性
    for prop_name, values in pairs(template.props) do
        equip.props[prop_name] = values[quality]
    end
    
    -- 查找空闲格子
    local bag_service = require "services.bag_service"
    local bag_type, slot_index = bag_service.find_empty_slot(user_id, enum.BagType.EQUIPMENT)
    
    if not bag_type or not slot_index then
        logger.error("No empty slot found for new equipment")
        return nil, "no empty slot"
    end
    
    -- 设置格子
    equip.bag_type = bag_type
    equip.slot_index = slot_index
    
    -- 添加到物品列表
    local ok = item_dao.add_user_item(user_id, equip)
    if not ok then
        logger.error("Failed to add random equipment for user %d", user_id)
        return nil, "add item failed"
    end
    
    -- 计算装备配置
    local equip_config = config_service.get_item_config(equip.item_id)
    
    return equip, nil, equip_config
end

-- 分解装备
function M.decompose_equipment(user_id, item_id)
    local config_service = require "services.config_service"
    local item_service = get_item_service()
    
    -- 获取物品信息
    local item = item_service.get_item(user_id, item_id)
    if not item then
        return false, "item not found"
    end
    
    -- 检查是否为装备
    local item_config = config_service.get_item_config(item.item_id)
    if not item_config or item_config.type ~= enum.ItemType.ITEM_TYPE_EQUIPMENT then
        return false, "item is not equipment"
    end
    
    -- 获取装备配置
    local equip_config = config_service.get_equipment_config(item.item_id)
    if not equip_config then
        return false, "equip config not found"
    end
    
    -- 获取分解奖励道具ID
    local reward_item_id = equip_config.split or 1004
    
    -- 根据品质和等级计算分解获得的数量
    local quality = item.quality or 1
    local level = item.level or 1
    
    -- 基础数量根据品质
    local base_count = quality * 10
    
    -- 根据等级增加数量
    local level_bonus = math.floor(level / 5) * 5
    
    -- 总数量
    local total_count = base_count + level_bonus
    
    -- 删除装备
    local ok, err = item_service.remove_item(user_id, item_id, 1)
    if not ok then
        return false, err
    end
    
    -- 添加奖励道具
    local reward_item, err = item_service.add_item(user_id, {
        item_id = reward_item_id,
        count = total_count
    })
    
    if not reward_item then
        return false, err
    end
    
    return true, nil, {
        item_id = reward_item_id,
        count = total_count
    }
end

-- 完善随机装备后的装备功能
function M.equip_random_item(user_id, item, is_replace)
    -- 检查物品是否为装备
    local config_service = require "services.config_service"
    local equip_config = config_service.get_equipment_config(item.item_id)
    if not equip_config then
        return false, "not an equipment"
    end
    
    -- 获取装备部位
    local part = math.floor((item.item_id - 3000) / 100)
    if part < 1 or part > 12 then
        return false, "invalid equipment part"
    end
    
    -- 如果不需要替换，直接添加到背包
    if not is_replace then
        return true, nil, item, nil, 0
    end
    
    -- 获取已装备的物品
    local equipments = M.get_equipments(user_id)
    local current_equip = equipments[part]
    
    -- 如果没有已装备物品，直接装备
    if not current_equip then
        -- 更新装备状态
        item.is_equipped = true
        item.equip_slot = part
        
        -- 保存更新
        local item_dao = require "dao.item_dao"
        local items = item_dao.get_user_items(user_id)
        if not items then
            items = {}
        end
        
        -- 找到对应物品并更新
        local found = false
        for _, it in ipairs(items) do
            if it.id == item.id then
                it.is_equipped = true
                it.equip_slot = part
                found = true
                break
            end
        end
        
        -- 如果没找到，添加到列表
        if not found then
            table.insert(items, item)
        end
        
        -- 保存更新
        local ok = item_dao.update_user_items(user_id, items)
        if not ok then
            return false, "save item failed"
        end
        
        -- 更新属性
        local property_service = require "services.property_service"
        property_service.recalc_equip_props(user_id)
        
        -- 计算战力变化
        local power_change = 0
        if equip_config.power then
            power_change = equip_config.power
        end
        
        return true, nil, item, nil, power_change
    end
    
    -- 对比新旧装备战力
    local current_config = config_service.get_equipment_config(current_equip.item_id)
    local power_diff = 0
    
    if equip_config.power and current_config.power then
        power_diff = equip_config.power - current_config.power
    end
    
    -- 如果新装备战力更高，替换
    if power_diff > 0 then
        -- 更新装备状态
        item.is_equipped = true
        item.equip_slot = part
        current_equip.is_equipped = false
        current_equip.equip_slot = nil
        
        -- 保存更新
        local item_dao = require "dao.item_dao"
        local items = item_dao.get_user_items(user_id)
        if not items then
            items = {}
        end
        
        -- 更新物品状态
        for _, it in ipairs(items) do
            if it.id == item.id then
                it.is_equipped = true
                it.equip_slot = part
            elseif it.id == current_equip.id then
                it.is_equipped = false
                it.equip_slot = nil
            end
        end
        
        -- 保存更新
        local ok = item_dao.update_user_items(user_id, items)
        if not ok then
            return false, "save item failed"
        end
        
        -- 更新属性
        local property_service = require "services.property_service"
        property_service.recalc_equip_props(user_id)
        
        return true, nil, item, current_equip, power_diff
    end
    
    -- 新装备战力不高，不替换
    return true, nil, item, current_equip, power_diff
end

-- 检查装备等级升级
function M.check_equipment_level_upgrades()
    local equipment_dao = require "dao.equipment_dao"
    local completed_upgrades = equipment_dao.get_completed_upgrades()
    
    local notify_service = require "services.notify_service"
    
    for _, upgrade in ipairs(completed_upgrades) do
        local ok, new_level = equipment_dao.complete_equip_level_upgrade(upgrade.user_id)
        if ok then
            logger.info("User %d equipment level upgraded to %d", upgrade.user_id, new_level)
            
            -- 通知用户
            notify_service.notify_equipment_level_upgraded(upgrade.user_id, new_level)
        else
            logger.error("Failed to complete equipment level upgrade for user %d", upgrade.user_id)
        end
    end
    
    return #completed_upgrades
end

function M.init_user_equip_slots(user_id)
    local ok = equipment_dao.init_user_equip_slots(user_id)
    return ok
end

-- 获取装备等级信息和品质概率
function M.get_equip_odds_level_info(user_id)
    if not user_id then
        return nil, "invalid user_id"
    end
    
    -- 从数据库获取用户当前装备等级
    local equipment_level_info = equipment_dao.get_equip_level_info(user_id)
    if not equipment_level_info then
        -- 如果没有记录，创建初始记录
        equipment_level_info = {
            user_id = user_id,
            current_level = 1,
            is_upgrading = false,
            upgrade_start_time = 0,
            upgrade_duration = 0
        }
        equipment_dao.save_equip_level_info(user_id, equipment_level_info)
    end
    
    -- 获取装备等级配置
    local equip_level_configs = config_service.get_all_equipment_level_configs()
    local current_level_config = equip_level_configs[equipment_level_info.current_level] or {}
    local next_level_config = equip_level_configs[equipment_level_info.current_level + 1] or {}
    
    -- 计算升级所需时间和剩余时间
    local upgrade_time = next_level_config.upgrade_time or 60  -- 默认60秒
    local remaining_time = 0
    
    if equipment_level_info.is_upgrading then
        local elapsed = os.time() - equipment_level_info.upgrade_start_time
        remaining_time = math.max(0, equipment_level_info.upgrade_duration - elapsed)
        
        -- 检查是否已完成
        if remaining_time <= 0 then
            -- 升级完成
            equipment_level_info.current_level = equipment_level_info.current_level + 1
            equipment_level_info.is_upgrading = false
            equipment_dao.save_equip_level_info(user_id, equipment_level_info)
            
            -- 更新配置
            current_level_config = next_level_config
            next_level_config = equip_level_configs[equipment_level_info.current_level + 1] or {}
        end
    end
    
    -- 获取品质概率配置
    local current_odds = current_level_config.quality_odds or {60, 25, 10, 4, 1}
    local next_odds = next_level_config.quality_odds or {55, 28, 12, 4, 1}
    
    -- 构建返回结果
    local max_level = 0
    for level, _ in pairs(equip_level_configs) do
        if level > max_level then
            max_level = level
        end
    end
    
    -- 升级所需材料
    local item_id = next_level_config.item_id or 1005  -- 默认使用道具1005
    local item_count = next_level_config.item_count or 10
    
    -- 获取用户拥有的物品数量
    local owned_count = 0
    local item_service = get_item_service()
    local user_items = item_service.get_user_items(user_id)
    for _, item in ipairs(user_items or {}) do
        if item.item_id == item_id then
            owned_count = owned_count + item.count
            break
        end
    end
    
    -- 返回结果
    return {
        current_level = equipment_level_info.current_level,
        max_level = max_level,
        item_id = item_id,
        item_count = item_count,
        owned_count = owned_count,
        upgrade_time = upgrade_time,
        remaining_time = remaining_time,
        is_upgrading = equipment_level_info.is_upgrading,
        current_odds = current_odds,
        next_odds = next_odds
    }
end

return M 