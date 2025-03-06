local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.mail_sql"
local db_util = require "db_proxy.utils.db_util"
local cjson = require "cjson"
local utils = require "utils"
local M = {}

-- 获取用户邮件列表
function M.get_user_mails(user_id)
    local results = db_util.execute(sql.GET_USER_MAILS, {
        user_id = user_id
    })
    
    if not results then
        logger.error("Failed to get mails for user: %d", user_id)
        return nil, "Database error"
    end
    
    -- 解析JSON字段
    for _, mail in ipairs(results) do
        logger.info("mail: %s", utils.table_to_string(mail))
        if mail.items and type(mail.items) == "string" then
            -- 移除可能的多余转义字符
            local items_str = mail.items:gsub('\\', '')
            local ok, items = pcall(cjson.decode, items_str)
            if ok then
                mail.items = items
            else
                logger.error("Failed to decode mail items: %s, error: %s", items_str, items)
                mail.items = {}
            end
        end
    end
    
    return results
end

-- 获取单个邮件
function M.get_mail(params)
    if not params.mail_id or not params.user_id then
        logger.error("get_mail: invalid params")
        return nil, "Invalid parameters"
    end
    
    local results = db_util.execute(sql.GET_MAIL, {
        mail_id = params.mail_id,
        user_id = params.user_id
    })
    
    if not results or #results == 0 then
        logger.error("Mail not found: %s for user: %d", params.mail_id, params.user_id)
        return nil, "Mail not found"
    end
    
    local mail = results[1]
    
    -- 解析JSON字段
    if mail.items and type(mail.items) == "string" then
        local items_str = mail.items:gsub('\\', '')
        local ok, items = pcall(cjson.decode, items_str)
        if ok then
            mail.items = items
        else
            logger.error("Failed to decode mail items: %s, error: %s", items_str, items)
            mail.items = {}
        end
    end
    
    return mail
end

-- 保存邮件
function M.save_mail(mail)
    -- 确保items是JSON字符串
    local items_json
    if type(mail.items) == "string" then
        items_json = mail.items
    else
        items_json = cjson.encode(mail.items or {})
        -- 确保不会有多余的转义
        items_json = items_json:gsub('\\', '')
    end
    
    local ok = db_util.execute(sql.SAVE_MAIL, {
        id = mail.id,
        user_id = mail.user_id,
        title = mail.title,
        content = mail.content,
        items = items_json,
        mail_type = mail.mail_type,
        status = mail.status,
        create_time = mail.create_time,
        update_time = mail.update_time or mail.create_time,
        expire_time = mail.expire_time,
        template_id = mail.template_id or 0,
        sender_id = mail.sender_id or 0,
        sender_name = mail.sender_name or ""
    })
    
    if not ok then
        logger.error("Failed to save mail: %s", mail.id)
        return false, "Database error"
    end
    
    return true
end

-- 保存邮件模板
function M.save_mail_template(template)
    -- JSON编码
    local items_json = type(template.items) == "string" and template.items or cjson.encode(template.items or {})
    local condition_json = type(template.condition_data) == "string" and template.condition_data or cjson.encode(template.condition_data or {})
    local sent_users_json = type(template.sent_users) == "string" and template.sent_users or cjson.encode(template.sent_users or {})
    
    local ok = db_util.execute(sql.SAVE_MAIL_TEMPLATE, {
        id = template.id,
        title = template.title,
        content = template.content,
        items = items_json,
        mail_type = template.mail_type,
        create_time = template.create_time,
        expire_time = template.expire_time,
        condition_data = condition_json,
        sent_users = sent_users_json
    })
    
    if not ok then
        logger.error("Failed to save mail template: %s", template.id)
        return false, "Database error"
    end
    
    return true
end

-- 更新邮件状态
function M.update_mail_status(params)
    local ok = db_util.execute(sql.UPDATE_MAIL_STATUS, {
        status = params.status,
        update_time = params.update_time,
        mail_id = params.mail_id,
        user_id = params.user_id
    })
    
    if not ok then
        logger.error("Failed to update mail status: %s", params.mail_id)
        return false, "Database error"
    end
    
    return true
end

-- 批量更新邮件状态
function M.batch_update_mail_status(params)
    local mail_ids_str = table.concat(
        table.map(params.mail_ids, function(id) return string.format("'%s'", id) end),
        ","
    )
    
    local ok = db_util.execute(sql.BATCH_UPDATE_MAIL_STATUS, {
        status = params.status,
        update_time = params.update_time,
        user_id = params.user_id,
        mail_ids = mail_ids_str
    })
    
    if not ok then
        logger.error("Failed to batch update mail status for user: %d", params.user_id)
        return false, "Database error"
    end
    
    return true
end

-- 删除邮件
function M.delete_mails(params)
    local mail_ids_str = table.concat(
        table.map(params.mail_ids, function(id) return string.format("'%s'", id) end),
        ","
    )
    
    local ok = db_util.execute(sql.DELETE_MAILS, {
        user_id = params.user_id,
        mail_ids = mail_ids_str
    })
    
    if not ok then
        logger.error("Failed to delete mails for user: %d", params.user_id)
        return false, "Database error"
    end
    
    return true
end

-- 删除过期邮件
function M.delete_expired_mails(current_time)
    local ok = db_util.execute(sql.DELETE_EXPIRED_MAILS, {
        current_time = current_time
    })
    
    if not ok then
        logger.error("Failed to delete expired mails")
        return false, "Database error"
    end
    
    return true
end

-- 获取邮件模板
function M.get_mail_template(template_id)
    local result = db_util.execute(sql.GET_MAIL_TEMPLATE, {
        template_id = template_id
    })
    
    if not result or #result == 0 then
        return nil
    end
    
    local template = result[1]
    
    -- 解析JSON字段
    if template.items then
        local ok, items = pcall(cjson.decode, template.items)
        if ok then
            template.items = items
        else
            template.items = {}
        end
    end
    
    if template.condition_data then
        local ok, condition = pcall(cjson.decode, template.condition_data)
        if ok then
            template.condition_data = condition
        else
            template.condition_data = {}
        end
    end
    
    if template.sent_users then
        local ok, sent_users = pcall(cjson.decode, template.sent_users)
        if ok then
            template.sent_users = sent_users
        else
            template.sent_users = {}
        end
    end
    
    return template
end

-- 获取有效的邮件模板
function M.get_valid_mail_templates(current_time)
    local results = db_util.execute(sql.GET_VALID_MAIL_TEMPLATES, {
        current_time = current_time
    })
    
    if not results then
        return {}
    end
    
    -- 解析所有模板的JSON字段
    for _, template in ipairs(results) do
        if template.items then
            local ok, items = pcall(cjson.decode, template.items)
            if ok then
                template.items = items
            else
                template.items = {}
            end
        end
        
        if template.condition_data then
            local ok, condition = pcall(cjson.decode, template.condition_data)
            if ok then
                template.condition_data = condition
            else
                template.condition_data = {}
            end
        end
        
        if template.sent_users then
            local ok, sent_users = pcall(cjson.decode, template.sent_users)
            if ok then
                template.sent_users = sent_users
            else
                template.sent_users = {}
            end
        end
    end
    
    return results
end

return M 