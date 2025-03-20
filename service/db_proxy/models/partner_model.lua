local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.partner_sql"
local db_util = require "db_proxy.utils.db_util"
local utils = require "utils"

local M = {}

-- 创建伙伴
function M.create_partner(partner)
    if not partner or not partner.id or not partner.user_id then
        return false, "Invalid partner info"
    end
    
    local query = string.format(sql.CREATE_PARTNER,
        partner.id,
        partner.user_id,
        partner.unit_id,
        partner.level,
        partner.exp,
        partner.star,
        partner.power,
        partner.create_time,
        partner.update_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to create partner for user: %d, unit_id: %d", 
            partner.user_id, partner.unit_id)
        return false, "Database error"
    end
    
    return true
end

-- 批量创建伙伴
function M.batch_create_partners(partners)
    if not partners or #partners == 0 then
        return false, "No partners to create"
    end
    
    for _, partner in ipairs(partners) do
        -- 插入数据库
        local query = string.format(sql.INSERT_PARTNER,
            partner.id,
            partner.user_id,
            partner.unit_id,
            partner.level,
            partner.exp,
            partner.star,
            partner.power,
            partner.create_time,
            partner.update_time
        )
        
        local ok = db_util.query(query)
        if not ok then
            logger.error("Failed to create partner for user: %d, unit_id: %d", 
                partner.user_id, partner.unit_id)
            return false, "Database error"
        end
    end
    
    return true
end

-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    local query = string.format(sql.GET_USER_PARTNERS, user_id)
    local results = db_util.query(query)
    
    if not results then
        logger.error("Failed to get partners for user: %d", user_id)
        return nil, "Database error"
    end
    
    -- 确保返回所有必要字段
    for _, partner in ipairs(results) do
        partner.exp = partner.exp or 0
        partner.power = partner.power or 0
        partner.properties = partner.properties or {}
    end
    
    return results
end

-- 获取伙伴信息
function M.get_partner(partner_id)
    local query = string.format(sql.GET_PARTNER, partner_id)
    local results = db_util.query(query)
    
    if not results or #results == 0 then
        logger.error("Failed to get partner: %d", partner_id)
        return nil, "Partner not found"
    end
    
    local partner = results[1]
    partner.properties = partner.properties or {}
    
    return partner
end

-- 更新伙伴信息
function M.update_partner(partner)
    if not partner or not partner.id or not partner.user_id then
        return false, "Invalid partner info"
    end
    
    local query = string.format(sql.UPDATE_PARTNER,
        partner.level,
        partner.exp,
        partner.star,
        partner.power,
        partner.update_time,
        partner.id,
        partner.user_id
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to update partner: %d", partner.id)
        return false, "Database error"
    end
    
    return true
end

-- 删除伙伴
function M.delete_partner(partner_id, user_id)
    local query = string.format(sql.DELETE_PARTNER, partner_id, user_id)
    local ok = db_util.query(query)
    
    if not ok then
        logger.error("Failed to delete partner: %d for user: %d", partner_id, user_id)
        return false, "Database error"
    end
    
    return true
end

-- 检查伙伴是否存在
function M.check_partner_exists(user_id, unit_id)
    local query = string.format(sql.CHECK_PARTNER_EXISTS, user_id, unit_id)
    local results = db_util.query(query)
    
    if not results or #results == 0 then
        return false, "Query failed"
    end
    
    return results[1].count > 0
end

-- 记录伙伴变化
function M.log_partner_change(log)
    if not log or not log.user_id or not log.partner_id then
        return false, "Invalid log info"
    end
    
    -- 确保所有字段都有合适的默认值
    local data = {
        partner_id = tonumber(log.partner_id),
        user_id = tonumber(log.user_id),
        change_type = tostring(log.change_type),
        old_value = tonumber(log.old_value) or 0,
        new_value = tonumber(log.new_value) or 0,
        operation_time = tonumber(log.change_time) or os.time(),
        consume_items = db_util.escape_string(log.extra_info or "[]")
    }
    
    -- 根据变化类型选择对应的SQL语句
    local query
    if data.change_type == "GM_SET_LEVEL" or data.change_type == "LEVEL_UP" then
        query = string.format(sql.LOG_PARTNER_LEVEL_CHANGE,
            data.partner_id, data.user_id,
            data.old_value, data.new_value,
            0, 0, -- old_exp, new_exp (暂时设为0，后续可以从partner对象中获取)
            data.consume_items,
            data.operation_time)
            
    elseif data.change_type == "GM_SET_STAR" or data.change_type == "STAR_UP" then
        query = string.format(sql.LOG_PARTNER_STAR_CHANGE,
            data.partner_id, data.user_id,
            data.old_value, data.new_value,
            data.consume_items,
            data.operation_time)
            
    elseif data.change_type == "GM_ADD" or data.change_type == "UNLOCK" then
        query = string.format(sql.LOG_PARTNER_UNLOCK,
            data.partner_id, data.user_id,
            data.old_value, -- unit_id
            data.new_value, -- fragment_count
            data.operation_time)
            
    else
        logger.error("Invalid change type: %s", data.change_type)
        return false, "Invalid change type"
    end
    
    -- 记录详细日志
    logger.debug("Executing partner change log query: %s", query)
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to log partner change for user: %d, partner_id: %d, type: %s", 
            data.user_id, data.partner_id, data.change_type)
        return false, "Database error"
    end
    
    return true
end

return M