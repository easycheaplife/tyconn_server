local skynet = require "skynet"
local logger = require "logger"
local item_service = require "services.item_service"
local user_service = require "services.user_service"
local mail_service = require "services.mail_service"
local utils = require "utils"
local enum = require "enum"
local partner_service = require "services.partner_service"

local M = {}

-- GM指令处理函数表
local GM_HANDLERS = {
    -- 添加物品
    add_item = function(user_id, params)
        if not params or #params < 2 then
            return {false, nil, "params not enough, usage: add_item <item_id> <count>"}
        end
        
        local item_id = tonumber(params[1])
        local count = tonumber(params[2])
        
        if not item_id or item_id <= 0 or not count or count <= 0 then
            return {false, nil, "invalid params"}
        end
        
        -- 添加物品
        local ok, err = item_service.add_items_to_slot(user_id, {
            {
                item_id = item_id,
                count = count
            }
        }, enum.ChangeSource.SOURCE_GM)
        logger.info("add_item - result: %s, err: %s", tostring(ok), tostring(err or "success"))
        
        if not ok then
            return {false, nil, err or "Failed to add item"}
        end
        
        return {true, string.format("Item added: %d x %d", item_id, count), nil}
    end,

    -- 删除物品
    del_item = function(user_id, params)
        if #params < 1 then
            return false, "params not enough"
        end

        local item_id = tonumber(params[1])
        local count = tonumber(params[2] or 1)
        
        if not item_id or count <= 0 then
            return false, "invalid params"
        end
        
        return item_service.batch_remove_items(user_id, {
            {
                item_id = item_id,
                count = count
            }
        })
    end,

    -- 清空背包
    clear_bag = function(user_id, args)
        -- 参数检查
        if not args[1] then
            return false, "missing bag type param"
        end
        
        local bag_type = tonumber(args[1])
        if not bag_type then
            return false, "bag type must be a number"
        end
        
        -- 调用背包服务清空背包
        local bag_service = require "services.bag_service"
        local ok, msg = bag_service.clear_bag(user_id, bag_type)
        if not ok then
            return false, msg
        end
        
        return true, "背包已清空"
    end,

    -- 设置等级
    set_level = function(user_id, params)
        if #params < 1 then
            return false, "params not enough"
        end
        
        local level = tonumber(params[1])
        logger.info("GM set level - level: %d", level)
        if not level or level <= 0 then
            return false, "invalid level param"
        end

        -- 计算所需经验值
        local need_exp = (level - 1) * 1000
        
        -- 获取当前用户信息
        logger.info("GM set level - user_id: %d, level: %d", user_id, level)
        local user = user_service.get_user_by_id(user_id)
        logger.info("GM set level - user: %s", utils.table_to_string(user))
        if not user then
            return false, "user not found"
        end

        if tonumber(user.level) >= tonumber(level) then
            return true, "level already reached"
        end
        -- 设置经验值会自动更新等级
        local ok, err = user_service.add_exp(user_id, need_exp - (user.exp or 0))
        if not ok then
            return false, err
        end
        logger.info("GM set level - ok: %s, err: %s", ok, err)
        return true, string.format("set level success: %d", level)
    end,

    -- 重置用户
    reset_user = function(user_id, params)
        return user_service.reset_user(user_id)
    end,

    -- 封禁用户
    ban_user = function(user_id, params)
        local target_id = tonumber(params[1])
        local duration = tonumber(params[2] or 3600) -- 默认1小时
        
        if not target_id or duration <= 0 then
            return false, "invalid params"
        end
        
        return user_service.ban_user(target_id, duration)
    end,

    -- 发送个人邮件
    send_mail = function(user_id, params)
        -- 参数检查: receive_user_id title content [item_id count]...
        if #params < 3 then
            logger.error("send_mail - params: %s", utils.table_to_string(params))
            return false, "Invalid parameters. Usage: send_mail receive_user_id title content [item_id count]..."
        end
        logger.info("send_mail - params: %s", utils.table_to_string(params))
        local receive_user_id = tonumber(params[1])
        local title = params[2]
        local content = params[3]
        
        -- 解析附件物品
        local items = {}
        for i = 4, #params, 2 do
            if i + 1 <= #params then
                table.insert(items, {
                    item_id = tonumber(params[i]),
                    count = tonumber(params[i + 1])
                })
            end
        end
        
        -- 获取发送者信息
        local sender = user_service.get_user_by_id(user_id)
        if not sender then
            return false, "Failed to get sender info"
        end
        -- 发送邮件
        local ok = mail_service.send_mail({
            user_id = receive_user_id,
            title = title,
            content = content,
            items = items,
            expire_time = nil,  -- 使用默认过期时间
            mail_type = enum.MailType.MAIL_TYPE_PERSONAL,
            template_id = nil,  -- template_id
            sender_id = user_id,  -- sender_id
            sender_name = sender.username  -- sender_name
        })
        
        if not ok then
            return false, "Failed to send mail"
        end
        
        return true, string.format("Mail sent to user %d", receive_user_id)
    end,

    -- 发送系统邮件
    send_system_mail = function(user_id, params)
        -- 参数检查: title content [item_id count]...
        if #params < 2 then
            return false, "Invalid parameters. Usage: send_system_mail title content [item_id count]..."
        end
        
        local title = params[1]
        local content = params[2]
        
        -- 解析附件物品
        local items = {}
        for i = 3, #params, 2 do
            if i + 1 <= #params then
                table.insert(items, {
                    item_id = tonumber(params[i]),
                    count = tonumber(params[i + 1])
                })
            end
        end
        
        -- 发送系统邮件
        local ok = mail_service.send_system_mail({
            title = title,
            content = content,
            items = items,
            expire_time = nil,  -- expire_time
            sender_id = 0,    -- sender_id (0 表示系统)
            sender_name = "系统"  -- sender_name
        })
        
        if not ok then
            return false, "Failed to send system mail"
        end
        
        return true, "System mail sent successfully"
    end,

    -- 添加伙伴
    add_partner = function(user_id, params)
        if not params or #params < 1 then
            return {false, nil, "Missing unit_id parameter"}
        end
        
        local unit_id = tonumber(params[1])
        if not unit_id then
            return {false, nil, "Invalid unit_id parameter"}
        end
        
        local ok, result, err = partner_service.gm_add_partner(user_id, unit_id)
        if not ok then
            return {false, nil, err or "Failed to add partner"}
        end
        
        return {true, result, nil}
    end,

    -- 添加伙伴碎片
    add_fragments = function(user_id, params)
        if not params or #params < 2 then
            return {false, nil, "Missing fragment_id or count parameter"}
        end
        
        local fragment_id = tonumber(params[1])
        local count = tonumber(params[2])
        
        if not fragment_id or not count then
            return {false, nil, "Invalid fragment_id or count parameter"}
        end
        
        local ok, result, err = partner_service.gm_add_fragments(user_id, fragment_id, count)
        if not ok then
            return {false, nil, err or "Failed to add fragments"}
        end
        
        return {true, result, nil}
    end,

    -- 设置伙伴等级
    set_partner_level = function(user_id, params)
        if not params or #params < 2 then
            return {false, nil, "Missing partner_id or level parameter"}
        end
        
        local partner_id = tonumber(params[1])
        local level = tonumber(params[2])
        
        if not partner_id or not level then
            return {false, nil, "Invalid partner_id or level parameter"}
        end
        
        local ok, result, err = partner_service.gm_set_partner_level(user_id, partner_id, level)
        if not ok then
            return {false, nil, err or "Failed to set partner level"}
        end
        
        return {true, result, nil}
    end,

    -- 设置伙伴星级
    set_partner_star = function(user_id, params)
        if not params or #params < 2 then
            return {false, nil, "Missing partner_id or star parameter"}
        end
        
        local partner_id = tonumber(params[1])
        local star = tonumber(params[2])
        
        if not partner_id or not star then
            return {false, nil, "Invalid partner_id or star parameter"}
        end
        
        local ok, result, err = partner_service.gm_set_partner_star(user_id, partner_id, star)
        if not ok then
            return {false, nil, err or "Failed to set partner star"}
        end
        
        return {true, result, nil}
    end
}

-- 执行GM指令
function M.execute_command(user_id, command, params)
    -- 1. 检查权限
    local ok, err = user_service.check_gm_permission(user_id)
    if not ok then
        return false, nil, err
    end

    -- 2. 获取命令处理器
    local handler = GM_HANDLERS[command]
    if not handler then
        logger.warn("Invalid GM command: %s", command)
        return false, nil, "unknown GM command"
    end

    -- 3. 执行命令
    local success, result, err = xpcall(function()
        return handler(user_id, params)
    end, debug.traceback)

    if not success then
        logger.error("GM command failed: %s", result)
        return false, nil, "GM command failed"
    end

    -- 4. 返回结果
    -- 处理不同类型的返回值
    if type(result) == "table" and result[1] ~= nil then
        -- 如果是表并且有至少一个元素，按约定返回 {ok, result, err}
        return result[1], result[2], result[3]
    elseif type(result) == "boolean" then
        -- 如果是布尔值，直接返回
        if result then
            -- 成功返回
            return true, "success", nil
        else
            -- 失败返回
            return false, nil, "command failed"
        end
    else
        -- 其他情况，返回原始结果
        return true, result, nil
    end
end

return M 