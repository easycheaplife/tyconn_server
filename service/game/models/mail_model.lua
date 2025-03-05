local snowflake = require "utils.snowflake"
local enum = require "game.define.enum"

local M = {}

-- 创建新邮件模型
function M.new(params)
    local now = os.time()
    return {
        -- 基础信息
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.MAIL),
        user_id = params.user_id,
        title = params.title,
        content = params.content,
        items = params.items or {},
        
        -- 邮件类型和状态
        mail_type = params.mail_type or enum.MailType.MAIL_TYPE_SYSTEM,
        status = params.status or enum.MailStatus.MAIL_STATUS_UNREAD,
        
        -- 时间相关
        create_time = params.create_time or now,
        expire_time = params.expire_time or (now + 7 * 24 * 3600),  -- 默认7天过期
        
        -- 模板相关
        template_id = params.template_id,
        
        -- 发送者信息(个人邮件)
        sender_id = params.sender_id,
        sender_name = params.sender_name
    }
end

-- 创建新邮件模板模型
function M.new_template(params)
    local now = os.time()
    return {
        -- 基础信息
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.MAIL_TEMPLATE),
        title = params.title,
        content = params.content,
        items = params.items or {},
        
        -- 邮件类型
        mail_type = params.mail_type or enum.MailType.MAIL_TYPE_SYSTEM,
        
        -- 时间相关
        create_time = params.create_time or now,
        expire_time = params.expire_time or (now + 7 * 24 * 3600),  -- 默认7天过期
        
        -- 发送条件
        condition_data = params.condition_data or {},
        
        -- 已发送用户列表
        sent_users = params.sent_users or {}
    }
end

-- 验证邮件数据
function M.validate(mail)
    if not mail then
        return false, "mail data is empty"
    end
    
    if not mail.user_id then
        return false, "user id is empty"
    end
    
    if not mail.title then
        return false, "title is empty"
    end
    
    if not mail.content then
        return false, "content is empty"
    end
    
    if mail.mail_type == enum.MailType.MAIL_TYPE_PERSONAL then
        if not mail.sender_id then
            return false, "sender id is required for personal mail"
        end
        if not mail.sender_name then
            return false, "sender name is required for personal mail"
        end
    end
    
    return true
end

-- 验证邮件模板数据
function M.validate_template(template)
    if not template then
        return false, "template data is empty"
    end
    
    if not template.title then
        return false, "title is empty"
    end
    
    if not template.content then
        return false, "content is empty"
    end
    
    if template.expire_time and template.expire_time <= os.time() then
        return false, "expire time is invalid"
    end
    
    return true
end

return M 