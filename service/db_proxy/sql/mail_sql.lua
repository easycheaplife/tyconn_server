local M = {}

-- 查询用户邮件列表
M.GET_USER_MAILS = {
    sql = [[
        SELECT *
        FROM mails 
        WHERE user_id = %d
        ORDER BY create_time DESC
    ]],
    params = {"user_id"}
}

-- 获取单个邮件
M.GET_MAIL = {
    sql = [[
        SELECT *
        FROM mails
        WHERE id = '%s' AND user_id = %d
    ]],
    params = {"mail_id", "user_id"}
}

-- 保存邮件
M.SAVE_MAIL = {
    sql = [[
        INSERT INTO mails (
            id, user_id, title, content,
            items, mail_type, status,
            create_time, update_time,
            expire_time, template_id, sender_id, sender_name
        ) VALUES (
            %s, %d, '%s', '%s',
            '%s', %d, %d,
            %d, %d,
            %d, %s, %s, %s
        ) ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            content = VALUES(content),
            items = VALUES(items),
            mail_type = VALUES(mail_type),
            status = VALUES(status),
            update_time = VALUES(update_time),
            expire_time = VALUES(expire_time),
            template_id = VALUES(template_id),
            sender_id = VALUES(sender_id),
            sender_name = VALUES(sender_name)
    ]],
    params = {
        "id", "user_id", "title", "content",
        "items", "mail_type", "status",
        "create_time", "update_time",
        "expire_time", "template_id", "sender_id", "sender_name"
    }
}

-- 保存邮件模板
M.SAVE_MAIL_TEMPLATE = {
    sql = [[
        INSERT INTO mail_templates (
            id, title, content, items,
            mail_type, create_time, expire_time,
            condition_data, sent_users
        ) VALUES (
            '%s', '%s', '%s', '%s',
            %d, %d, %d,
            '%s', '%s'
        )
    ]],
    params = {
        "id", "title", "content", "items",
        "mail_type", "create_time", "expire_time",
        "condition_data", "sent_users"
    }
}

-- 更新邮件状态
M.UPDATE_MAIL_STATUS = {
    sql = [[
        UPDATE mails 
        SET status = %d,
            update_time = %d
        WHERE id = '%s' AND user_id = %d
    ]],
    params = {"status", "update_time", "mail_id", "user_id"}
}

-- 批量更新邮件状态
M.BATCH_UPDATE_MAIL_STATUS = {
    sql = [[
        UPDATE mails 
        SET status = %d,
            update_time = %d
        WHERE user_id = %d AND id IN (%s)
    ]],
    params = {"status", "update_time", "user_id", "mail_ids"}
}

-- 删除邮件
M.DELETE_MAILS = {
    sql = [[
        DELETE FROM mails 
        WHERE user_id = %d AND id IN (%s)
    ]],
    params = {"user_id", "mail_ids"}
}

-- 删除过期邮件
M.DELETE_EXPIRED_MAILS = {
    sql = [[
        DELETE FROM mails 
        WHERE expire_time < %d
    ]],
    params = {"current_time"}
}

-- 获取邮件模板
M.GET_MAIL_TEMPLATE = {
    sql = [[
        SELECT *
        FROM mail_templates
        WHERE id = '%s'
    ]],
    params = {"template_id"}
}

-- 获取有效的邮件模板
M.GET_VALID_MAIL_TEMPLATES = {
    sql = [[
        SELECT *
        FROM mail_templates
        WHERE expire_time > %d
        ORDER BY create_time DESC
    ]],
    params = {"current_time"}
}

return M 