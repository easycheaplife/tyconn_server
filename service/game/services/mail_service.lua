local skynet = require "skynet"
local logger = require "logger"
local db_client = require "db_client"
local snowflake = require "utils.snowflake"
local enum = require "game.define.enum"
local mail_dao = require "dao.mail_dao"
local mail_model = require "models.mail_model"
local utils = require "utils"
local table = require "table"

local M = {}

-- 邮件缓存
local mail_cache = {}

-- 获取用户邮件列表
function M.get_user_mails(user_id)
    local mails = mail_dao.get_user_mails(user_id)
    
    -- 过滤掉已删除的邮件
    local filtered_mails = {}
    for _, mail in ipairs(mails) do
        if mail.status ~= enum.MailStatus.MAIL_STATUS_DELETED then
            table.insert(filtered_mails, mail)
        end
    end
    
    return filtered_mails
end

-- 发送系统邮件
function M.send_system_mail(params)
    -- 获取所有在线用户
    local online_service = require "services.online_service"
    local online_users = online_service.get_all_online_users()
    
    -- 创建系统邮件模板
    local mail_template = {
        id = snowflake.next_id(snowflake.ID_TYPE.MAIL),
        title = params.title,
        content = params.content,
        items = params.items or {},
        mail_type = enum.MailType.MAIL_TYPE_SYSTEM,
        create_time = os.time(),
        expire_time = params.expire_time or (os.time() + 7 * 24 * 3600),
        sender_id = params.sender_id or 0,
        sender_name = params.sender_name or "系统"
    }
    
    -- 保存邮件模板
    local ok = mail_dao.save_mail_template(mail_template)
    if not ok then
        logger.error("Failed to save mail template")
        return false
    end
    
    -- 给每个在线用户发送邮件
    for _, user_id in ipairs(online_users) do
        local mail_params = utils.deep_copy(mail_template)
        mail_params.user_id = user_id
        mail_params.template_id = mail_template.id
        M.send_mail(mail_params)
    end
    
    return true
end

-- 发送个人邮件
function M.send_personal_mail(user_id, title, content, items, expire_time)
    return M.send_mail(user_id, title, content, items, expire_time, enum.MailType.MAIL_TYPE_PERSONAL)
end

-- 基础发送邮件函数
function M.send_mail(params)
    -- Validate required parameters
    if not params.user_id or not params.title or not params.content then
        logger.error("send_mail: missing required parameters - params: %s", 
            utils.table_to_string(params))
        return false, "Missing required parameters"
    end

    -- Set default values if not provided
    params.mail_type = params.mail_type or enum.MailType.MAIL_TYPE_SYSTEM
    params.status = params.status or enum.MailStatus.MAIL_STATUS_UNREAD
    params.create_time = params.create_time or os.time()
    params.update_time = params.update_time or params.create_time
    params.expire_time = params.expire_time or (params.create_time + 7 * 24 * 3600)  -- Default 7 days expiry
    params.items = params.items or {}
    
    -- Generate mail ID if not provided
    params.id = params.id or snowflake.next_id(snowflake.ID_TYPE.MAIL)
    
    -- Save the mail
    local ok, err = mail_dao.save_mail(params)
    if not ok then
        logger.error("Failed to send mail: %s", err)
        return false, err
    end
    
    return true
end

-- 给新用户发送未收到的系统邮件
function M.sync_system_mails(user_id)
    -- 获取用户注册时间
    local user_service = require "services.user_service"
    local register_time = user_service.get_register_time(user_id)
    if not register_time then
        return false
    end
    
    -- 获取该时间段内的系统邮件模板
    local templates = db_client.find("mail_templates", {
        mail_type = enum.MailType.MAIL_TYPE_SYSTEM,
        create_time = {["$gt"] = register_time},
        expire_time = {["$gt"] = os.time()}
    })
    
    -- 检查用户是否已收到这些邮件
    for _, template in ipairs(templates) do
        local exists = db_client.find_one("mails", {
            user_id = user_id,
            template_id = template.template_id
        })
        
        if not exists then
            -- 发送未收到的系统邮件
            M.send_mail(user_id, template.title, template.content, 
                utils.deep_copy(template.items), template.expire_time, 
                enum.MailType.MAIL_TYPE_SYSTEM, template.template_id)
        end
    end
    
    return true
end

-- 标记邮件为已读
function M.mark_mail_read(user_id, mail_id)
    local mails = M.get_user_mails(user_id)
    for _, mail in ipairs(mails) do
        if mail.id == mail_id then
            mail.status = enum.MailStatus.MAIL_STATUS_READ
            -- 更新数据库
            db_client.update("mails", {id = mail_id}, {status = enum.MailStatus.MAIL_STATUS_READ})
            return true
        end
    end
    return false
end

-- 领取邮件附件
function M.claim_mail_items(user_id, mail_id)
    if not user_id or not mail_id then
        logger.error("claim_mail_items: invalid params - user_id: %s, mail_id: %s", 
            tostring(user_id), tostring(mail_id))
        return false
    end
    logger.info("claim_mail_items: user_id: %s, mail_id: %s", user_id, mail_id)
    
    -- 获取邮件信息
    local mail = mail_dao.get_mail(mail_id, user_id)
    if not mail then
        logger.error("Mail not found - user_id: %d, mail_id: %s", user_id, mail_id)
        return false
    end
    logger.info("claim_mail_items: mail: %s", utils.table_to_string(mail))
    
    -- 检查是否已领取
    if mail.status == enum.MailStatus.MAIL_STATUS_CLAIMED then
        logger.info("Mail items already claimed, returning existing items - user_id: %d, mail_id: %s", 
            user_id, mail_id)
        return true, mail.items or {}
    end
    
    logger.info("claim_mail_items: mail.items: %s", utils.table_to_string(mail.items))
    
    -- 将物品添加到用户背包
    if mail.items and #mail.items > 0 then
        local item_service = require "services.item_service"
        local ok, err = item_service.add_items_to_slot(user_id, mail.items, enum.ChangeSource.SOURCE_MAIL)
        if not ok then
            logger.error("Failed to add items to user bag - user_id: %d, error: %s", user_id, err)
            return false
        end
        logger.info("Items added to user bag successfully - user_id: %d", user_id)
    end
    
    -- 更新邮件状态为已领取
    local ok = mail_dao.update_mail_status(
        mail_id,
        user_id,
        enum.MailStatus.MAIL_STATUS_CLAIMED
    )
    logger.info("claim_mail_items: update status result: %s", tostring(ok))

    if not ok then
        logger.error("Failed to update mail status to claimed - user_id: %d, mail_id: %s",
            user_id, mail_id)
        -- 即使状态更新失败，我们也返回物品，因为已经添加到背包了
        logger.warn("Failed to update mail status, but items were added successfully")
        return true, mail.items or {}
    end

    -- 强制清除缓存，确保下次获取时能获取到最新状态
    mail_dao.clear_user_mails_cache(user_id)

    logger.info("claim_mail_items: mail.items: %s", utils.table_to_string(mail.items))
    
    -- 返回附件物品列表
    return true, mail.items or {}
end

-- 删除过期邮件
function M.delete_expired_mails()
    local now = os.time()
    local expired = db_client.find("mails", {expire_time = {["$lt"] = now}})
    
    for _, mail in ipairs(expired) do
        -- 标记为过期
        mail.status = enum.MailStatus.MAIL_STATUS_EXPIRED
        db_client.update("mails", {id = mail.id}, {status = enum.MailStatus.MAIL_STATUS_EXPIRED})
        
        -- 从缓存中删除
        if mail_cache[mail.user_id] then
            for i, m in ipairs(mail_cache[mail.user_id]) do
                if m.id == mail.id then
                    table.remove(mail_cache[mail.user_id], i)
                    break
                end
            end
        end
    end
    
    -- 从数据库删除
    db_client.delete("mails", {expire_time = {["$lt"] = now}})
end

-- 清理缓存
function M.clear_cache(user_id)
    mail_cache[user_id] = nil
end

-- 批量标记邮件为已读
function M.batch_mark_read(user_id, mail_ids)
    if not mail_ids or #mail_ids == 0 then
        return false
    end
    
    local mails = M.get_user_mails(user_id)
    local updated = false
    
    for _, mail in ipairs(mails) do
        for _, mail_id in ipairs(mail_ids) do
            if mail.id == mail_id and mail.status == enum.MailStatus.MAIL_STATUS_UNREAD then
                mail.status = enum.MailStatus.MAIL_STATUS_READ
                updated = true
            end
        end
    end
    
    if updated then
        -- 批量更新数据库
        db_client.update_many("mails", {
            id = {["$in"] = mail_ids},
            user_id = user_id,
            status = enum.MailStatus.MAIL_STATUS_UNREAD
        }, {
            status = enum.MailStatus.MAIL_STATUS_READ
        })
    end
    
    return true
end

-- 批量领取邮件附件
function M.batch_claim_items(user_id, mail_ids)
    if not mail_ids or #mail_ids == 0 then
        return false
    end
    
    local mails = M.get_user_mails(user_id)
    local items_to_add = {}
    local mails_to_update = {}
    
    -- 收集所有要领取的物品
    for _, mail in ipairs(mails) do
        for _, mail_id in ipairs(mail_ids) do
            if mail.id == mail_id and mail.status ~= enum.MailStatus.MAIL_STATUS_CLAIMED then
                for _, item in ipairs(mail.items) do
                    table.insert(items_to_add, item)
                end
                table.insert(mails_to_update, mail_id)
            end
        end
    end
    
    if #items_to_add > 0 then
        -- 添加物品到背包
        local item_service = require "services.item_service"
        local ok, err = item_service.add_items_to_slot(user_id, items_to_add, enum.ChangeSource.SOURCE_MAIL)
        if not ok then
            return false, err
        end
        
        -- 批量更新邮件状态
        db_client.update_many("mails", {
            id = {["$in"] = mails_to_update},
            user_id = user_id
        }, {
            status = enum.MailStatus.MAIL_STATUS_CLAIMED
        })
        
        -- 更新缓存
        for _, mail in ipairs(mails) do
            for _, mail_id in ipairs(mails_to_update) do
                if mail.id == mail_id then
                    mail.status = enum.MailStatus.MAIL_STATUS_CLAIMED
                end
            end
        end
    end
    
    return true
end

-- 批量删除已读且无附件或已领取附件的邮件
function M.batch_delete_mails(user_id, mail_ids)
    if not mail_ids or #mail_ids == 0 then
        return false
    end
    
    local mails = M.get_user_mails(user_id)
    local mails_to_delete = {}
    
    for _, mail in ipairs(mails) do
        for _, mail_id in ipairs(mail_ids) do
            if mail.id == mail_id then
                -- 只能删除已读且无附件或已领取附件的邮件
                if (mail.status == enum.MailStatus.MAIL_STATUS_READ and #mail.items == 0) or
                   mail.status == enum.MailStatus.MAIL_STATUS_CLAIMED then
                    table.insert(mails_to_delete, mail_id)
                end
            end
        end
    end
    
    if #mails_to_delete > 0 then
        -- 从数据库删除
        db_client.delete_many("mails", {
            id = {["$in"] = mails_to_delete},
            user_id = user_id
        })
        
        -- 从缓存删除
        if mail_cache[user_id] then
            local i = 1
            while i <= #mail_cache[user_id] do
                local mail = mail_cache[user_id][i]
                local should_delete = false
                for _, mail_id in ipairs(mails_to_delete) do
                    if mail.id == mail_id then
                        should_delete = true
                        break
                    end
                end
                if should_delete then
                    table.remove(mail_cache[user_id], i)
                else
                    i = i + 1
                end
            end
        end
    end
    
    return true
end

-- 获取指定类型的邮件
function M.get_mails_by_type(user_id, mail_type)
    local mails = M.get_user_mails(user_id)
    local filtered = {}
    
    for _, mail in ipairs(mails) do
        if mail.mail_type == mail_type then
            table.insert(filtered, mail)
        end
    end
    
    return filtered
end

-- 获取未读邮件
function M.get_unread_mails(user_id)
    local mails = M.get_user_mails(user_id)
    local unread = {}
    
    for _, mail in ipairs(mails) do
        if mail.status == enum.MailStatus.MAIL_STATUS_UNREAD then
            table.insert(unread, mail)
        end
    end
    
    return unread
end

-- 获取可领取附件的邮件
function M.get_claimable_mails(user_id)
    local mails = M.get_user_mails(user_id)
    local claimable = {}
    
    for _, mail in ipairs(mails) do
        if #mail.items > 0 and mail.status ~= enum.MailStatus.MAIL_STATUS_CLAIMED then
            table.insert(claimable, mail)
        end
    end
    
    return claimable
end

-- 获取邮件统计信息
function M.get_mail_stats(user_id)
    local mails = M.get_user_mails(user_id)
    local stats = {
        total = #mails,
        unread = 0,
        system = 0,
        personal = 0,
        with_items = 0,
        unclaimed = 0,
        expired = 0
    }
    
    for _, mail in ipairs(mails) do
        if mail.status == enum.MailStatus.MAIL_STATUS_UNREAD then
            stats.unread = stats.unread + 1
        end
        if mail.mail_type == enum.MailType.MAIL_TYPE_SYSTEM then
            stats.system = stats.system + 1
        else
            stats.personal = stats.personal + 1
        end
        if #mail.items > 0 then
            stats.with_items = stats.with_items + 1
            if mail.status ~= enum.MailStatus.MAIL_STATUS_CLAIMED then
                stats.unclaimed = stats.unclaimed + 1
            end
        end
        if mail.status == enum.MailStatus.MAIL_STATUS_EXPIRED then
            stats.expired = stats.expired + 1
        end
    end
    
    return stats
end

-- 发送欢迎邮件
function M.send_welcome_mail(user_id, username)
    -- 创建欢迎邮件
    local mail = mail_model.new({
        user_id = user_id,
        title = "欢迎来到游戏",
        content = string.format("亲爱的%s，欢迎来到我们的游戏世界！\n\n这是一份新手礼包，希望能帮助你更好地开始冒险之旅。", username),
        mail_type = enum.MailType.MAIL_TYPE_SYSTEM,
        items = {
            -- 新手礼包物品
            {
                item_id = 1001,  -- 金币
                count = 10000
            },
            {
                item_id = 2001,  
                count = 5
            }
        }
    })

    -- 保存邮件
    local ok, err = mail_dao.save_mail(mail)
    if not ok then
        logger.error("Failed to send welcome mail to user %d: %s", user_id, err)
        return false
    end

    logger.info("Welcome mail sent to user %d", user_id)
    return true
end

-- 读取邮件
function M.read_mail(user_id, mail_id)
    if not user_id or not mail_id then
        logger.error("read_mail: invalid params - user_id: %s, mail_id: %s", 
            tostring(user_id), tostring(mail_id))
        return false
    end

    -- 更新邮件状态为已读
    local ok = mail_dao.update_mail_status(
        mail_id,
        user_id,
        enum.MailStatus.MAIL_STATUS_READ
    )

    if not ok then
        logger.error("Failed to update mail status to read - user_id: %d, mail_id: %s",
            user_id, mail_id)
        return false
    end

    return true
end

-- 删除邮件
function M.delete_mail(user_id, mail_id)
    if not user_id or not mail_id then
        logger.error("delete_mail: invalid params - user_id: %s, mail_id: %s", 
            tostring(user_id), tostring(mail_id))
        return false
    end

    -- 更新邮件状态为已删除
    local ok = mail_dao.update_mail_status(
        mail_id,
        user_id,
        enum.MailStatus.MAIL_STATUS_DELETED
    )

    if not ok then
        logger.error("Failed to update mail status to deleted - user_id: %d, mail_id: %s",
            user_id, mail_id)
        return false
    end

    return true
end

return M 