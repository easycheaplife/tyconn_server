local skynet = require "skynet"
local logger = require "logger"
local cache = require "game.cache"
local db_client = require "game.db_client"
local snowflake = require "utils.snowflake"
local utils = require "utils"
local enum = require "game.define.enum"
local cjson = require "cjson"

local M = {}

-- 初始化用户装备槽
function M.init_user_equip_slots(user_id)
    local now = os.time()
    local slots = {
        {slot_id = 1, name = "武器"},  -- 武器
        {slot_id = 2, name = "护甲"},  -- 护甲
        {slot_id = 3, name = "头盔"},  -- 头盔
        {slot_id = 4, name = "项链"},  -- 项链
        {slot_id = 5, name = "戒指"},  -- 戒指
        {slot_id = 6, name = "靴子"}   -- 靴子
    }
    
    -- 检查是否已存在
    local count = db_client.check_equip_slots_exist(user_id)
    if count and count > 0 then
        -- 已存在，不需要初始化
        return true
    end
    
    -- 批量插入槽位记录
    local slot_data = {}
    for _, slot in ipairs(slots) do
        table.insert(slot_data, {
            user_id = user_id,
            slot_id = slot.slot_id,
            item_id = nil,
            expire_time = 0,
            equip_time = 0,
            update_time = now
        })
    end
    
    local ok = db_client.init_equip_slots(user_id, slot_data)
    if not ok then
        logger.error("Failed to init equipment slots for user %d", user_id)
        return false
    end
    
    -- 初始化装备等级记录
    local level_data = {
        user_id = user_id,
        level = 1,
        is_upgrading = 0,
        upgrade_start_time = 0,
        upgrade_end_time = 0,
        update_time = now
    }
    
    ok = db_client.init_equip_level(user_id, level_data)
    if not ok then
        logger.error("Failed to init equipment level for user %d", user_id)
        -- 继续执行，不会影响装备槽
    end
    
    return true
end

-- 获取用户装备槽
function M.get_user_equip_slots(user_id)
    -- 先尝试从缓存获取
    local slots = cache.get_equip_slots(user_id)
    if slots then
        return slots
    end
    
    -- 从数据库获取
    slots = db_client.get_equip_slots(user_id)
    if not slots then
        return {}
    end
    
    -- 保存到缓存
    cache.set_equip_slots(user_id, slots)
    
    return slots
end

-- 获取用户装备等级
function M.get_user_equip_level(user_id)
    -- 先尝试从缓存获取
    local level_data = cache.get_equip_level(user_id)
    if level_data then
        return level_data
    end
    
    -- 从数据库获取
    level_data = db_client.get_equip_level(user_id)
    if not level_data then
        -- 创建默认等级数据
        local now = os.time()
        level_data = {
            user_id = user_id,
            level = 1,
            is_upgrading = 0,
            upgrade_start_time = 0,
            upgrade_end_time = 0,
            update_time = now
        }
        
        -- 初始化到数据库
        local ok = db_client.init_equip_level(user_id, level_data)
        if not ok then
            logger.error("Failed to init default equipment level for user %d", user_id)
        end
    end
    
    -- 保存到缓存
    cache.set_equip_level(user_id, level_data)
    
    return level_data
end

-- 装备物品到槽位
function M.equip_item_to_slot(user_id, slot_id, item_id, expire_time)
    -- 更新数据库
    local ok = db_client.update_equip_slot(user_id, slot_id, item_id, expire_time)
    if not ok then
        logger.error("Failed to equip item %s to slot %d for user %d", 
            item_id, slot_id, user_id)
        return false
    end
    
    -- 清除缓存
    cache.remove_equip_slots(user_id)
    
    return true
end

-- 从槽位卸下物品
function M.unequip_item_from_slot(user_id, slot_id)
    -- 更新数据库
    local ok = db_client.update_equip_slot(user_id, slot_id, nil, 0)
    if not ok then
        logger.error("Failed to unequip item from slot %d for user %d", 
            slot_id, user_id)
        return false
    end
    
    -- 清除缓存
    cache.remove_equip_slots(user_id)
    
    return true
end

-- 开始装备等级升级
function M.start_equip_level_upgrade(user_id, start_time, end_time)
    -- 获取当前等级信息
    local level_data = M.get_user_equip_level(user_id)
    if not level_data then
        logger.error("Failed to get equipment level for user %d", user_id)
        return false
    end
    
    -- 检查是否已在升级中
    if level_data.is_upgrading == 1 then
        logger.warn("Equipment level already upgrading for user %d", user_id)
        return false
    end
    
    -- 更新等级信息
    local update_params = {
        user_id = user_id,
        is_upgrading = 1,
        upgrade_start_time = start_time,
        upgrade_end_time = end_time,
        update_time = os.time()
    }
    
    local ok = db_client.update_equip_level(update_params)
    if not ok then
        logger.error("Failed to start equipment level upgrade for user %d", user_id)
        return false
    end
    
    -- 清除缓存
    cache.remove_equip_level(user_id)
    
    return true
end

-- 完成装备等级升级
function M.complete_equip_level_upgrade(user_id)
    -- 获取当前等级信息
    local level_data = M.get_user_equip_level(user_id)
    if not level_data then
        logger.error("Failed to get equipment level for user %d", user_id)
        return false, nil
    end
    
    -- 检查是否正在升级
    if level_data.is_upgrading ~= 1 then
        logger.warn("Equipment level not upgrading for user %d", user_id)
        return false, nil
    end
    
    -- 新等级
    local new_level = level_data.level + 1
    
    -- 更新等级信息
    local update_params = {
        user_id = user_id,
        level = new_level,
        is_upgrading = 0,
        upgrade_start_time = 0,
        upgrade_end_time = 0,
        update_time = os.time()
    }
    
    local ok = db_client.update_equip_level(update_params)
    if not ok then
        logger.error("Failed to complete equipment level upgrade for user %d", user_id)
        return false, nil
    end
    
    -- 清除缓存
    cache.remove_equip_level(user_id)
    
    return true, new_level
end

-- 获取所有已完成的升级
function M.get_completed_upgrades()
    return db_client.get_completed_equip_upgrades()
end

-- 获取过期装备
function M.get_expired_equipment(user_id)
    return db_client.get_expired_equipment(user_id)
end

-- 检查升级是否完成
function M.is_upgrade_completed(user_id)
    local level_data = M.get_user_equip_level(user_id)
    if not level_data or not level_data.is_upgrading or level_data.is_upgrading == 0 then
        return false, level_data
    end
    
    local now = os.time()
    if level_data.upgrade_end_time > 0 and level_data.upgrade_end_time <= now then
        return true, level_data
    end
    
    return false, level_data
end

-- 清除缓存
function M.clear_cache(user_id)
    return cache.clear_equip_cache(user_id)
end

-- 获取装备等级信息 (为保持API兼容性)
function M.get_equip_level_info(user_id)
    -- 直接使用现有的get_user_equip_level函数
    local level_data = M.get_user_equip_level(user_id)
    if not level_data then
        return nil
    end
    
    -- 转换为equip_service.lua期望的格式
    return {
        user_id = level_data.user_id,
        current_level = level_data.level,
        is_upgrading = level_data.is_upgrading == 1,
        upgrade_start_time = level_data.upgrade_start_time,
        upgrade_duration = level_data.upgrade_end_time > 0 
            and (level_data.upgrade_end_time - level_data.upgrade_start_time) 
            or 0
    }
end

-- 保存装备等级信息 (为保持API兼容性)
function M.save_equip_level_info(user_id, info)
    if not user_id or not info then
        return false
    end
    
    -- 准备更新参数
    local update_params = {
        user_id = user_id,
        level = info.current_level,
        is_upgrading = info.is_upgrading and 1 or 0,
        upgrade_start_time = info.upgrade_start_time or 0,
        upgrade_end_time = info.is_upgrading and 
            (info.upgrade_start_time + info.upgrade_duration) or 0,
        update_time = os.time()
    }
    
    -- 使用现有的数据库更新函数
    local ok = db_client.update_equip_level(update_params)
    if not ok then
        logger.error("Failed to save equipment level info for user %d", user_id)
        return false
    end
    
    -- 清除缓存
    cache.remove_equip_level(user_id)
    
    return true
end

return M 