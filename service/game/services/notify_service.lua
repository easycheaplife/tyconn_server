local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local gate_client = require "gate_client"
local user_session_service = require "services.user_session_service"

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
    -- 获取用户会话
    local session = user_session_service.get_session_by_user_id(user_id)
    if not session then
        return
    end
    
    -- 构造推送消息
    local notify = {
        type = "new_mail",
        mail = {
            id = mail.id,
            title = mail.title,
            mail_type = mail.mail_type,
            status = mail.status,
            has_items = #mail.items > 0
        }
    }
    
    -- 发送到网关
    cluster.send(session.gate_node, ".gate", "push_message", user_id, "NOTIFY_NEW_MAIL", notify)
end

return M 