local M = {}

-- 检查用户装备槽是否已存在
M.CHECK_EQUIP_SLOTS_EXIST = [[
    SELECT COUNT(*) as count
    FROM user_equipment_slots
    WHERE user_id = %d
]]

-- 获取用户装备槽
M.GET_EQUIP_SLOTS = [[
    SELECT 
        user_id,
        slot_id,
        item_id,
        expire_time,
        equip_time,
        update_time
    FROM user_equipment_slots
    WHERE user_id = %d
    ORDER BY slot_id ASC
]]

-- 获取用户装备等级
M.GET_EQUIP_LEVEL = [[
    SELECT 
        user_id,
        level,
        is_upgrading,
        upgrade_start_time,
        upgrade_end_time,
        update_time
    FROM user_equipment_levels
    WHERE user_id = %d
]]

-- 更新装备槽
M.UPDATE_EQUIP_SLOT = [[
    UPDATE user_equipment_slots
    SET item_id = %s,
        expire_time = %d,
        equip_time = %d,
        update_time = %d
    WHERE user_id = %d AND slot_id = %d
]]

-- 更新装备等级
M.UPDATE_EQUIP_LEVEL = [[
    UPDATE user_equipment_levels
    SET %s
    WHERE user_id = %d
]]

-- 获取已完成升级的装备等级
M.GET_COMPLETED_UPGRADES = [[
    SELECT 
        user_id,
        level,
        upgrade_start_time,
        upgrade_end_time
    FROM user_equipment_levels
    WHERE is_upgrading = 1 
    AND upgrade_end_time > 0 
    AND upgrade_end_time <= %d
]]

-- 获取过期装备
M.GET_EXPIRED_EQUIPMENT = [[
    SELECT 
        s.user_id,
        s.slot_id,
        s.item_id,
        s.expire_time,
        i.*
    FROM user_equipment_slots s
    JOIN user_items i ON s.item_id = i.id
    WHERE s.user_id = %d 
    AND s.expire_time > 0 
    AND s.expire_time <= %d
]]

-- 初始化装备槽批量插入
M.INIT_EQUIP_SLOTS = [[
    INSERT INTO user_equipment_slots (
        user_id, 
        slot_id, 
        item_id, 
        expire_time, 
        equip_time, 
        update_time
    ) VALUES 
]]

-- 初始化装备等级
M.INIT_EQUIP_LEVEL = [[
    INSERT INTO user_equipment_levels (
        user_id,
        level,
        is_upgrading,
        upgrade_start_time,
        upgrade_end_time,
        update_time
    ) VALUES (
        %d,
        %d,
        %d,
        %d,
        %d,
        %d
    )
]]

-- 获取装备属性
M.GET_EQUIP_PROPERTIES = [[
    SELECT 
        id,
        equip_id,
        part,
        quality,
        level,
        additional_props,
        create_time,
        update_time
    FROM equip_properties
    WHERE equip_id = %d
]]

-- 插入装备属性
M.INSERT_EQUIP_PROPERTIES = [[
    INSERT INTO equip_properties (
        equip_id,
        part,
        quality,
        level,
        additional_props,
        create_time,
        update_time
    ) VALUES (
        %d,
        %d,
        %d,
        %d,
        %s,
        %d,
        %d
    )
]]

-- 更新装备属性
M.UPDATE_EQUIP_PROPERTIES = [[
    UPDATE equip_properties
    SET additional_props = %s,
        part = %d,
        quality = %d,
        level = %d,
        update_time = %d
    WHERE equip_id = %d
]]

return M 