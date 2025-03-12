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
    
    -- 构建日志字段
    local fields = {
        "user_id", "partner_id", "change_type", "change_desc", 
        "old_value", "new_value", "change_time"
    }
    local values = {
        log.user_id, log.partner_id, log.change_type, 
        log.change_desc or "", log.old_value or "", 
        log.new_value or "", log.change_time or os.time()
    }
    
    -- 构建SQL字段和值
    local field_str = table.concat(fields, ", ")
    local value_placeholders = {}
    for i = 1, #values do
        if type(values[i]) == "string" then
            value_placeholders[i] = string.format("'%s'", db_util.escape_string(values[i]))
        else
            value_placeholders[i] = tostring(values[i])
        end
    end
    local value_str = table.concat(value_placeholders, ", ")
    
    -- 构建SQL语句
    local query = string.format(
        "INSERT INTO partner_change_logs (%s) VALUES (%s)",
        field_str, value_str
    )
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to log partner change for user: %d, partner_id: %d", 
            log.user_id, log.partner_id)
        return false, "Database error"
    end
    
    return true
end

return M