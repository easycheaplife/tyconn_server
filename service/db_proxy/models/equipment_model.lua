local db_util = require "db_proxy.utils.db_util"
local equipment_sql = require "db_proxy.sql.equipment_sql"
local logger = require "logger"
local cjson = require "cjson"

local M = {}

-- 检查用户装备槽是否存在
function M.check_equip_slots_exist(user_id)
    local query = string.format(equipment_sql.CHECK_EQUIP_SLOTS_EXIST, user_id)
    local result = db_util.query(query)
    if not result or #result == 0 then
        return { count = 0 }
    end
    
    return result[1]
end

-- 获取用户装备槽
function M.get_equip_slots(user_id)
    local query = string.format(equipment_sql.GET_EQUIP_SLOTS, user_id)
    return db_util.query(query)
end

-- 获取用户装备等级
function M.get_equip_level(user_id)
    local query = string.format(equipment_sql.GET_EQUIP_LEVEL, user_id)
    return db_util.query(query)
end

-- 更新装备槽
function M.update_equip_slot(params)
    -- 参数验证
    if not params.user_id or not params.slot_id then
        logger.error("update_equip_slot: missing required params")
        return false
    end
    
    -- 构造 SQL SET 子句中的 item_id 部分
    local item_id_str = params.item_id and ("'" .. params.item_id .. "'") or "NULL"
    
    local query = string.format(
        equipment_sql.UPDATE_EQUIP_SLOT, 
        item_id_str,
        params.expire_time or 0,
        params.equip_time or os.time(),
        params.update_time or os.time(),
        params.user_id,
        params.slot_id
    )
    
    return db_util.query(query) ~= nil
end

-- 更新装备等级
function M.update_equip_level(params)
    -- 参数验证
    if not params.user_id then
        logger.error("update_equip_level: missing user_id")
        return false
    end
    
    -- 构造 SET 子句
    local set_parts = {}
    if params.level then
        table.insert(set_parts, string.format("level = %d", params.level))
    end
    if params.is_upgrading ~= nil then
        table.insert(set_parts, string.format("is_upgrading = %d", params.is_upgrading))
    end
    if params.upgrade_start_time then
        table.insert(set_parts, string.format("upgrade_start_time = %d", params.upgrade_start_time))
    end
    if params.upgrade_end_time then
        table.insert(set_parts, string.format("upgrade_end_time = %d", params.upgrade_end_time))
    end
    if params.update_time then
        table.insert(set_parts, string.format("update_time = %d", params.update_time))
    end
    
    local set_clause = table.concat(set_parts, ", ")
    
    -- 检查是否有更新内容
    if set_clause == "" then
        return false
    end
    
    local query = string.format(
        equipment_sql.UPDATE_EQUIP_LEVEL,
        set_clause,
        params.user_id
    )
    
    return db_util.query(query) ~= nil
end

-- 初始化装备槽
function M.init_equip_slots(params)
    -- 参数验证
    if not params.user_id or not params.slots or #params.slots == 0 then
        logger.error("init_equip_slots: invalid params")
        return false
    end
    
    -- 构造批量插入的值部分
    local values = {}
    for _, slot in ipairs(params.slots) do
        local item_id_str = slot.item_id and ("'" .. slot.item_id .. "'") or "NULL"
        table.insert(values, string.format(
            "(%d, %d, %s, %d, %d, %d)",
            params.user_id,
            slot.slot_id,
            item_id_str,
            slot.expire_time or 0,
            slot.equip_time or 0,
            slot.update_time or os.time()
        ))
    end
    
    local query = equipment_sql.INIT_EQUIP_SLOTS .. table.concat(values, ", ")
    
    return db_util.query(query) ~= nil
end

-- 初始化装备等级
function M.init_equip_level(params)
    -- 参数验证
    if not params.user_id then
        logger.error("init_equip_level: missing user_id")
        return false
    end
    
    local query = string.format(
        equipment_sql.INIT_EQUIP_LEVEL,
        params.user_id,
        params.level or 1,
        params.is_upgrading or 0,
        params.start_time or 0,
        params.end_time or 0,
        params.update_time or os.time()
    )
    
    return db_util.query(query) ~= nil
end

-- 获取已完成的升级
function M.get_completed_equip_upgrades(current_time)
    local query = string.format(equipment_sql.GET_COMPLETED_UPGRADES, current_time)
    return db_util.query(query) or {}
end

-- 获取过期装备
function M.get_expired_equipment(params)
    -- 参数验证
    if not params.user_id or not params.current_time then
        logger.error("get_expired_equipment: missing required params")
        return {}
    end
    
    local query = string.format(equipment_sql.GET_EXPIRED_EQUIPMENT, 
        params.user_id, params.current_time)
    local result = db_util.query(query)
    
    -- 处理JSON字段
    if result then
        for _, item in ipairs(result) do
            if item.props and item.props ~= "" then
                local ok, decoded = pcall(cjson.decode, item.props)
                if ok then
                    item.props = decoded
                else
                    item.props = {}
                    logger.error("Failed to decode props for item %s", item.id)
                end
            else
                item.props = {}
            end
        end
    end
    
    return result or {}
end

-- 获取装备属性
function M.get_equip_properties(equip_id)
    if not equip_id then
        logger.error("get_equip_properties: missing equip_id")
        return nil
    end
    
    local query = string.format(equipment_sql.GET_EQUIP_PROPERTIES, equip_id)
    local result = db_util.query(query)
    
    if result and result[1] then
        -- 解析 JSON 属性
        if result[1].additional_props then
            local ok, decoded = pcall(cjson.decode, result[1].additional_props)
            if ok then
                result[1].additional_props = decoded
            else
                result[1].additional_props = {}
                logger.error("Failed to decode additional_props for equip %d", equip_id)
            end
        end
        return result[1]
    end
    
    return nil
end

-- 插入装备属性
function M.insert_equip_properties(params)
    if not params.equip_id or not params.additional_props then
        logger.error("insert_equip_properties: missing required params")
        return false
    end
    
    -- 参数验证
    if not params.part or not params.quality or not params.level then
        logger.error("insert_equip_properties: missing part, quality or level")
        return false
    end
    
    -- 将 additional_props 转换为 JSON 字符串
    local additional_props_json = cjson.encode(params.additional_props)
    local current_time = os.time()
    local query = string.format(
        equipment_sql.INSERT_EQUIP_PROPERTIES,
        params.equip_id,
        params.part,
        params.quality,
        params.level,
        "'" .. additional_props_json .. "'",
        params.create_time or current_time,
        params.update_time or current_time
    )
    
    return db_util.query(query) ~= nil
end

-- 更新装备属性
function M.update_equip_properties(params)
    if not params.equip_id or not params.additional_props then
        logger.error("update_equip_properties: missing required params")
        return false
    end
    
    -- 参数验证
    if not params.part or not params.quality or not params.level then
        logger.error("update_equip_properties: missing part, quality or level")
        return false
    end
    
    -- 将 additional_props 转换为 JSON 字符串
    local additional_props_json = cjson.encode(params.additional_props)
    local query = string.format(
        equipment_sql.UPDATE_EQUIP_PROPERTIES,
        "'" .. additional_props_json .. "'",
        params.part,
        params.quality,
        params.level,
        params.update_time or os.time(),
        params.equip_id
    )
    
    return db_util.query(query) ~= nil
end

return M 