local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local gate_client = require "gate_client"
local user_session_service = require "services.user_session_service"
local utils = require "utils"

local M = {}

-- 已有的通知函数...

-- 通知装备过期
function M.notify_equipment_expired(user_id, expired_items)
    if not user_id or not expired_items or #expired_items == 0 then
        return false
    end
    
    -- 创建装备过期推送消息
    local push_data = {
        expired_items = expired_items
    }
    
    -- 将消息推送给用户
    local message_id = pb.enum("common.MessageID", "G2C_EQUIPMENT_EXPIRED_PUSH")
    local ok = gate_client.push_message(user_id, message_id, push_data)
    
    if ok then
        logger.info("Notified user %d about %d expired equipment items", user_id, #expired_items)
    else
        logger.error("Failed to notify user %d about expired equipment", user_id)
    end
    
    return ok
end

-- 通知装备等级升级完成
function M.notify_equipment_level_upgraded(user_id, new_level)
    if not user_id then
        return false
    end
    
    -- 创建装备等级升级推送消息
    local push_data = {
        new_level = new_level
    }
    
    -- 将消息推送给用户
    local message_id = pb.enum("common.MessageID", "G2C_EQUIPMENT_LEVEL_UPGRADED_PUSH")
    local ok = gate_client.push_message(user_id, message_id, push_data)
    
    if ok then
        logger.info("Notified user %d about equipment level upgrade to %d", user_id, new_level)
    else
        logger.error("Failed to notify user %d about equipment level upgrade", user_id)
    end
    
    return ok
end

-- 推送新邮件通知
function M.push_new_mail(user_id, mail)
    if not user_id or not mail then
        logger.error("push_new_mail: missing required parameters - user_id: %s, mail: %s", 
            tostring(user_id), tostring(mail))
        return false
    end
    
    -- 获取用户会话信息
    local session = user_session_service.get_session_by_user_id(user_id)
    if not session then
        logger.error("push_new_mail: user session not found - user_id: %d", user_id)
        return false
    end
    
    if not session.gate_node then
        logger.error("push_new_mail: gate node not found for user %d", user_id)
        return false
    end
    
    -- 创建新邮件推送消息
    local push_data = {
        mail = {
            id = mail.id,
            title = mail.title,
            mail_type = mail.mail_type,
            status = mail.status,
            has_items = mail.items and #mail.items > 0 or false
        }
    }
    
    -- 添加详细日志记录
    logger.debug("push_new_mail: Creating push data for user %d", user_id)
    logger.debug("push_new_mail: Mail ID: %s", tostring(mail.id))
    logger.debug("push_new_mail: Mail Title: %s", tostring(mail.title))
    logger.debug("push_new_mail: Message ID: %d", pb.enum("common.MessageID", "G2C_NEW_MAIL_PUSH"))
    
    -- 将消息推送给用户
    local message_id = pb.enum("common.MessageID", "G2C_NEW_MAIL_PUSH")
    local ok, err = pcall(function()
        return gate_client.push_message(user_id, message_id, push_data)
    end)
    
    if not ok then
        logger.error("push_new_mail: failed to push message - user_id: %d, error: %s", user_id, tostring(err))
        return false
    end
    
    if ok then
        logger.info("Notified user %d about new mail %d: %s", user_id, mail.id, mail.title)
    else
        logger.error("Failed to notify user %d about new mail %d", user_id, mail.id)
    end
    
    return ok
end

return M 