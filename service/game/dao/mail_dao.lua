local skynet = require "skynet"
local logger = require "logger"
local db_client = require "game.db_client"
local cache = require "game.cache"
local utils = require "utils"
local mail_model = require "models.mail_model"

local M = {}

-- 从数据库获取用户邮件列表
function M.get_user_mails(user_id)
    if not user_id then
        return {}
    end
    
    -- 1. 从缓存获取
    local mails = cache.get_user_mails(user_id)
    if mails then
        return mails
    end
    
    -- 2. 从数据库加载
    local result = db_client.get_user_mails(user_id)
    
    -- 3. 写入缓存
    if result then
        cache.set_user_mails(user_id, result)
        return result
    end
    
    return {}
end

-- 获取单个邮件
function M.get_mail(mail_id, user_id)
    if not mail_id or not user_id then
        logger.error("get_mail: invalid params - mail_id: %s, user_id: %s", 
            tostring(mail_id), tostring(user_id))
        return nil
    end
    
    -- 1. 从缓存获取
    local mails = cache.get_user_mails(user_id)
    if mails then
        for _, mail in ipairs(mails) do
            if mail.id == mail_id then
                return mail
            end
        end
    end
    
    -- 2. 从数据库加载单个邮件
    local mail = db_client.get_mail(mail_id, user_id)
    if not mail then
        logger.error("Mail not found - mail_id: %s, user_id: %d", mail_id, user_id)
        return nil
    end
    
    return mail
end

-- 保存邮件
function M.save_mail(params)
    -- 1. 创建邮件模型
    local mail = mail_model.new(params)
    
    -- 2. 验证数据
    local ok, err = mail_model.validate(mail)
    if not ok then
        return false, err
    end
    
    -- 3. 写入数据库
    ok = db_client.save_mail(mail)
    if not ok then
        return false, "Failed to save mail"
    end
    
    -- 4. 清除缓存
    cache.remove_user_mails(mail.user_id)
    
    return true
end

-- 保存邮件模板
function M.save_mail_template(params)
    -- 1. 创建模板模型
    local template = mail_model.new_template(params)
    
    -- 2. 验证数据
    local ok, err = mail_model.validate_template(template)
    if not ok then
        return false, err
    end
    
    -- 3. 写入数据库
    return db_client.save_mail_template(template)
end

-- 更新邮件状态
function M.update_mail_status(mail_id, user_id, status)
    if not mail_id or not user_id or not status then
        logger.error("update_mail_status: invalid params - mail_id: %s, user_id: %s, status: %s", 
            tostring(mail_id), tostring(user_id), tostring(status))
        return false
    end
    
    -- 确保 mail_id 是字符串格式
    local mail_id_str = tostring(mail_id)
    logger.info("Updating mail status - mail_id: %s, user_id: %d, status: %d", 
        mail_id_str, user_id, status)
    
    -- 1. 更新数据库
    local ok = db_client.update_mail_status(mail_id_str, user_id, status)
    if not ok then
        logger.error("Failed to update mail status in database - mail_id: %s, user_id: %d", 
            mail_id_str, user_id)
        return false
    end
    
    -- 2. 更新缓存
    local mails = cache.get_user_mails(user_id)
    if mails then
        for _, mail in ipairs(mails) do
            -- 确保都是字符串比较
            if tostring(mail.id) == mail_id_str then
                mail.status = status
                logger.info("Updated mail status in cache - mail_id: %s, status: %d", mail_id_str, status)
                break
            end
        end
        -- 刷新缓存
        cache.set_user_mails(user_id, mails)
        logger.info("Cache updated for user: %d", user_id)
    end
    
    return true
end

-- 批量更新邮件状态
function M.batch_update_mail_status(user_id, mail_ids, status)
    if not user_id or not mail_ids or #mail_ids == 0 or not status then
        return false, "Invalid parameters"
    end
    
    -- 1. 批量更新数据库
    local ok = db_client.batch_update_mail_status(user_id, mail_ids, status)
    
    -- 2. 清除缓存
    if ok then
        cache.remove_user_mails(user_id)
    end
    
    return ok
end

-- 删除邮件
function M.delete_mails(user_id, mail_ids)
    if not user_id or not mail_ids or #mail_ids == 0 then
        return false, "Invalid parameters"
    end
    
    -- 1. 从数据库删除
    local ok = db_client.delete_mails(user_id, mail_ids)
    
    -- 2. 清除缓存
    if ok then
        cache.remove_user_mails(user_id)
    end
    
    return ok
end

-- 删除过期邮件
function M.delete_expired_mails()
    -- 1. 获取过期邮件的用户ID列表
    local ok = db_client.delete_expired_mails()
    if not ok then
        return false
    end
    
    return true
end

return M 