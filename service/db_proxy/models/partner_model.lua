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
    
    -- 根据变化类型选择对应的日志表
    local table_name
    if log.change_type == "LEVEL_UP" then
        table_name = "partner_level_logs"
    elseif log.change_type == "STAR_UP" then
        table_name = "partner_star_logs"
    elseif log.change_type == "UNLOCK" then
        table_name = "partner_unlock_logs"
    else
        logger.error("Invalid change type: %s", log.change_type)
        return false
    end
    
    -- 构建SQL语句
    local query
    if log.change_type == "LEVEL_UP" then
        query = string.format([[
            INSERT INTO partner_level_logs (
                partner_id, user_id, old_level, new_level, 
                old_exp, new_exp, consume_items, operation_time
            ) VALUES (
                %d, %d, %d, %d, 
                0, 0, %s, %d
            )
        ]], log.partner_id, log.user_id, log.old_value, log.new_value, 
            log.consume_items and string.format("'%s'", db_util.escape_string(log.consume_items)) or "NULL",
            log.operation_time)
    elseif log.change_type == "STAR_UP" then
        query = string.format([[
            INSERT INTO partner_star_logs (
                partner_id, user_id, old_star, new_star, 
                consume_items, operation_time
            ) VALUES (
                %d, %d, %d, %d, 
                %s, %d
            )
        ]], log.partner_id, log.user_id, log.old_value, log.new_value,
            log.consume_items and string.format("'%s'", db_util.escape_string(log.consume_items)) or "NULL",
            log.operation_time)
    elseif log.change_type == "UNLOCK" then
        query = string.format([[
            INSERT INTO partner_unlock_logs (
                partner_id, user_id, unit_id, fragment_count, 
                operation_time
            ) VALUES (
                %d, %d, %d, %d, 
                %d
            )
        ]], log.partner_id, log.user_id, log.old_value, log.new_value, log.operation_time)
    end
    
    local ok = db_util.query(query)
    if not ok then
        logger.error("Failed to log partner change for user: %d, partner_id: %d", 
            log.user_id, log.partner_id)
        return false, "Database error"
    end
    
    return true
end

return M