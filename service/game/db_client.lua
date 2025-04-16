local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local utils = require "utils"
local balancer_service = require "balancer_service"

local M = {}

-- 调用数据库服务
local function call_db(...)
    -- 从balancer获取db_proxy节点
    local node = balancer_service.get_node("db_proxy", skynet.getenv("node_name"))
    -- 使用 @node 作为服务名，因为是跨节点调用
    return cluster.call(node, "@"..node, ...)
end

-- 批量创建卡牌
function M.batch_create_cards(cards)
    return call_db("batch_create_cards", cards)
end

-- 获取用户卡牌列表
function M.get_user_cards(user_id)
    if not user_id then
        logger.error("get_user_cards: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_user_cards", user_id)
    if not ok then
        logger.error("Failed to get user cards: %s", result)
        return nil
    end
    
    return result
end

-- 更新卡牌信息
function M.update_card(card)
    return call_db("update_card", card)
end

-- 获取用户信息
function M.get_user(account)
    return call_db("get_user", account)
end

-- 创建用户
function M.create_user(user)
    return call_db("create_user", user)
end

-- 获取用户物品
function M.get_user_items(user_id)
    return call_db("get_user_items", user_id)
end

-- 更新用户物品
function M.update_user_items(user_id, items)
    return call_db("update_user_items", user_id, items)
end

-- 更新单个物品
function M.update_single_item(item)
    if not item or not item.id or not item.user_id then
        logger.error("update_single_item: invalid item data")
        return false
    end
    
    local update_data = {
        id = item.id,
        user_id = item.user_id,
        item_id = item.item_id,
        count = item.count,
        bag_type = item.bag_type,
        slot_index = item.slot_index,
        update_time = os.time()
    }
    
    local ok, result = pcall(call_db, "update_single_item", update_data)
    if not ok then
        logger.error("Failed to update single item: %s, error: %s", 
            utils.table_to_string(update_data), result)
        return false
    end
    
    return result
end

-- 添加单个物品
function M.add_single_item(item)
    if not item or not item.id or not item.user_id or not item.item_id then
        logger.error("add_single_item: invalid item data")
        return false
    end
    
    -- 确保有创建和更新时间
    if not item.create_time then 
        item.create_time = os.time()
    end
    if not item.update_time then
        item.update_time = os.time()
    end
    
    local ok, result = pcall(call_db, "add_single_item", item)
    if not ok then
        logger.error("Failed to add single item: %s, error: %s", 
            utils.table_to_string(item), result)
        return false
    end
    
    return result
end

-- 删除单个物品
function M.delete_single_item(item_id, user_id)
    if not item_id or not user_id then
        logger.error("delete_single_item: invalid item_id or user_id")
        return false
    end
    
    local ok, result = pcall(call_db, "delete_single_item", {
        id = item_id,
        user_id = user_id
    })
    
    if not ok then
        logger.error("Failed to delete single item: id=%s, user_id=%d, error: %s", 
            tostring(item_id), user_id, result)
        return false
    end
    
    return result
end

-- 记录物品变化
function M.log_item_change(user_id, item_id, count, type, source, before_count, after_count)
    -- 添加参数检查
    if not user_id then
        logger.error("log_item_change: missing user_id")
        return false
    end
    if not item_id then
        logger.error("log_item_change: missing item_id")
        return false
    end
    if not count then
        logger.error("log_item_change: missing count")
        return false
    end
    if not type then
        logger.error("log_item_change: missing type")
        return false
    end
    if not source then
        logger.error("log_item_change: missing source")
        return false
    end
    
    return call_db("log_item_change", {
        user_id = user_id,
        item_id = item_id,
        count = count,
        type = type,
        source = source or "unknown",  -- 提供默认值
        before_count = before_count or 0,  -- 提供默认值
        after_count = after_count or 0,    -- 提供默认值
        create_time = os.time()
    })
end

-- 更新用户信息
function M.update_user(user_info)
    if not user_info or not user_info.user_id then
        logger.error("update_user: invalid user info")
        return nil
    end

    local ok, result = pcall(call_db, "update_user", user_info)
    if not ok then
        logger.error("Failed to update user: %s, error: %s", 
            utils.table_to_string(user_info), result)
        return nil
    end

    return result
end

-- 创建卡牌
function M.create_card(card)
    return call_db("create_card", card)
end

-- 获取用户背包
function M.get_user_bag(user_id, bag_type)
    return call_db("get_user_bag", user_id, bag_type)
end

-- 获取用户背包列表
function M.get_user_bags(user_id)
    return call_db("get_user_bags", user_id)
end

-- 获取背包格子状态
function M.get_bag_slots(user_id, bag_type)
    return call_db("get_bag_slots", user_id, bag_type)
end

-- 更新用户背包
function M.update_user_bag(user_id, bag_type, bag_data)
    return call_db("update_user_bag", user_id, bag_type, bag_data)
end

-- 创建用户背包
function M.create_user_bag(params)
    -- 检查参数
    if not params or not params.user_id or not params.bag_type or not params.size then
        logger.error("Invalid params for create_user_bag: %s", utils.table_to_string(params))
        return false
    end

    -- 调用数据库服务
    local ok, result = pcall(call_db, "create_user_bag", params)
    if not ok then
        logger.error("Failed to create user bag: %s", result)
        return false
    end

    return result
end

-- 删除用户背包
function M.delete_user_bag(user_id, bag_type)
    return call_db("delete_user_bag", user_id, bag_type)
end

-- 批量创建格子
function M.batch_create_slots(slots)
    -- 转换格子数据为数据库格式
    local db_slots = {}
    for _, slot in ipairs(slots) do
        table.insert(db_slots, {
            id = slot.id,  -- 使用 snowflake 生成的 ID
            user_id = slot.user_id,
            bag_type = slot.bag_type,
            slot_index = slot.slot_index,
            state = slot.state,
            create_time = os.time(),
            update_time = os.time()
        })
    end
    return call_db("batch_create_slots", db_slots)
end

-- 更新格子状态
function M.update_slot_state(user_id, bag_type, slot_index, state)
    return call_db("update_slot_state", {
        user_id = user_id,
        bag_type = bag_type,
        slot_index = slot_index,
        state = state,
        update_time = os.time()
    })
end

-- 更新背包大小
function M.update_bag_size(user_id, bag_type, new_size)
    -- 检查参数
    if not user_id or not bag_type or not new_size then
        logger.error("update_bag_size: invalid params, user_id: %d, bag_type: %d, new_size: %d",
            user_id, bag_type, new_size)
        return false
    end

    -- 调用数据库服务
    local ok, result = pcall(call_db, "update_bag_size", {
        user_id = user_id,
        bag_type = bag_type,
        size = new_size,
        update_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to update bag size: %s", result)
        return false
    end

    return result
end

-- 检查用户装备槽是否存在
function M.check_equip_slots_exist(user_id)
    if not user_id then
        logger.error("check_equip_slots_exist: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "check_equip_slots_exist", user_id)
    if not ok then
        logger.error("Failed to check equip slots exist: %s", result)
        return nil
    end
    
    return result and result.count
end

-- 获取用户装备槽
function M.get_equip_slots(user_id)
    if not user_id then
        logger.error("get_equip_slots: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_equip_slots", user_id)
    if not ok then
        logger.error("Failed to get equip slots: %s", result)
        return nil
    end
    
    return result
end

-- 获取用户装备等级
function M.get_equip_level(user_id)
    if not user_id then
        logger.error("get_equip_level: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_equip_level", user_id)
    if not ok then
        logger.error("Failed to get equip level: %s", result)
        return nil
    end
    
    return result and result[1]
end

-- 更新装备槽位
function M.update_equip_slot(user_id, slot_id, item_id, expire_time)
    if not user_id or not slot_id then
        logger.error("update_equip_slot: invalid params, user_id: %s, slot_id: %s", 
            tostring(user_id), tostring(slot_id))
        return false
    end
    
    local ok, result = pcall(call_db, "update_equip_slot", {
        user_id = user_id,
        slot_id = slot_id,
        item_id = item_id,
        expire_time = expire_time or 0,
        equip_time = item_id and os.time() or 0,
        update_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to update equip slot: %s", result)
        return false
    end
    
    return result
end

-- 更新装备等级
function M.update_equip_level(params)
    if not params or not params.user_id then
        logger.error("update_equip_level: missing user_id")
        return false
    end
    
    -- 确保有更新的内容
    if not params.level and not params.is_upgrading and 
       not params.upgrade_start_time and not params.upgrade_end_time then
        logger.error("update_equip_level: no update fields")
        return false
    end
    
    params.update_time = os.time()
    
    local ok, result = pcall(call_db, "update_equip_level", params)
    if not ok then
        logger.error("Failed to update equip level: %s", result)
        return false
    end
    
    return result
end

-- 初始化装备槽
function M.init_equip_slots(user_id, slots)
    if not user_id or not slots or #slots == 0 then
        logger.error("init_equip_slots: invalid params")
        return false
    end
    
    local ok, result = pcall(call_db, "init_equip_slots", {
        user_id = user_id,
        slots = slots
    })
    
    if not ok then
        logger.error("Failed to init equip slots: %s", result)
        return false
    end
    
    return result
end

-- 初始化装备等级
function M.init_equip_level(user_id, level_data)
    if not user_id or not level_data then
        logger.error("init_equip_level: invalid params")
        return false
    end
    
    level_data.user_id = user_id
    level_data.update_time = level_data.update_time or os.time()
    
    local ok, result = pcall(call_db, "init_equip_level", level_data)
    if not ok then
        logger.error("Failed to init equip level: %s", result)
        return false
    end
    
    return result
end

-- 获取已完成的升级
function M.get_completed_equip_upgrades()
    local current_time = os.time()
    
    local ok, result = pcall(call_db, "get_completed_equip_upgrades", current_time)
    if not ok then
        logger.error("Failed to get completed equip upgrades: %s", result)
        return {}
    end
    
    return result or {}
end

-- 获取过期装备
function M.get_expired_equipment(user_id)
    if not user_id then
        logger.error("get_expired_equipment: user_id is nil")
        return {}
    end
    
    local current_time = os.time()
    
    local ok, result = pcall(call_db, "get_expired_equipment", {
        user_id = user_id,
        current_time = current_time
    })
    
    if not ok then
        logger.error("Failed to get expired equipment: %s", result)
        return {}
    end
    
    return result or {}
end

-- 获取用户邮件列表
function M.get_user_mails(user_id)
    if not user_id then
        logger.error("get_user_mails: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_user_mails", user_id)
    if not ok then
        logger.error("Failed to get user mails: %s", result)
        return nil
    end
    return result
end

-- 获取单个邮件
function M.get_mail(mail_id, user_id)
    if not mail_id or not user_id then
        logger.error("get_mail: invalid params")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_mail", {
        mail_id = mail_id,
        user_id = user_id
    })
    
    if not ok then
        logger.error("Failed to get mail: %s", result)
        return nil
    end
    
    return result
end

-- 保存邮件
function M.save_mail(mail)
    if not mail or not mail.id or not mail.user_id then
        logger.error("save_mail: invalid mail data")
        return false
    end
    
    local ok, result = pcall(call_db, "save_mail", mail)
    if not ok then
        logger.error("Failed to save mail: %s", result)
        return false
    end
    
    return result
end

-- 保存邮件模板
function M.save_mail_template(template)
    if not template or not template.id then
        logger.error("save_mail_template: invalid template data")
        return false
    end
    
    local ok, result = pcall(call_db, "save_mail_template", template)
    if not ok then
        logger.error("Failed to save mail template: %s", result)
        return false
    end
    
    return result
end

-- 更新邮件状态
function M.update_mail_status(mail_id, user_id, status, update_time)
    if not mail_id or not user_id or not status then
        logger.error("update_mail_status: invalid parameters")
        return false
    end
    
    local ok, result = pcall(call_db, "update_mail_status", {
        mail_id = mail_id,
        user_id = user_id,
        status = status,
        update_time = update_time or os.time()
    })
    
    if not ok then
        logger.error("Failed to update mail status: %s", result)
        return false
    end
    
    return result
end

-- 批量更新邮件状态
function M.batch_update_mail_status(user_id, mail_ids, status)
    if not user_id or not mail_ids or #mail_ids == 0 or not status then
        logger.error("batch_update_mail_status: invalid parameters")
        return false
    end
    
    local ok, result = pcall(call_db, "batch_update_mail_status", {
        user_id = user_id,
        mail_ids = mail_ids,
        status = status,
        update_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to batch update mail status: %s", result)
        return false
    end
    
    return result
end

-- 删除邮件
function M.delete_mails(user_id, mail_ids)
    if not user_id or not mail_ids or #mail_ids == 0 then
        logger.error("delete_mails: invalid parameters")
        return false
    end
    
    local ok, result = pcall(call_db, "delete_mails", {
        user_id = user_id,
        mail_ids = mail_ids
    })
    
    if not ok then
        logger.error("Failed to delete mails: %s", result)
        return false
    end
    
    return result
end

-- 删除过期邮件
function M.delete_expired_mails()
    local ok, result = pcall(call_db, "delete_expired_mails", os.time())
    if not ok then
        logger.error("Failed to delete expired mails: %s", result)
        return false
    end
    
    return result
end

-- 获取邮件模板
function M.get_mail_template(template_id)
    if not template_id then
        logger.error("get_mail_template: template_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_mail_template", template_id)
    if not ok then
        logger.error("Failed to get mail template: %s", result)
        return nil
    end
    
    return result
end

-- 获取有效的邮件模板列表
function M.get_valid_mail_templates()
    local current_time = os.time()
    
    local ok, result = pcall(call_db, "get_valid_mail_templates", current_time)
    if not ok then
        logger.error("Failed to get valid mail templates: %s", result)
        return {}
    end
    
    return result or {}
end

-- 更新用户登录时间
function M.update_user_login_time(user_id, login_time)
    local ok, err = call_db("update_user_login_time", {
        user_id = user_id,
        login_time = login_time
    })
    
    if not ok then
        logger.error("DB client error when updating login time: %s", err or "unknown error")
        return false, err
    end
    
    return true
end

-- 伙伴相关数据库操作
-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    if not user_id then
        logger.error("get_user_partners: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_user_partners", user_id)
    if not ok then
        logger.error("Failed to get user partners: %s", result)
        return nil
    end
    
    return result
end

-- 获取特定伙伴
function M.get_partner(partner_id)
    if not partner_id then
        logger.error("get_partner: partner_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_partner", partner_id)
    if not ok then
        logger.error("Failed to get partner: %s", result)
        return nil
    end
    
    return result
end

-- 创建伙伴
function M.create_partner(partner)
    if not partner or not partner.user_id or not partner.unit_id then
        logger.error("create_partner: invalid partner data")
        return false
    end
    
    local ok, result = pcall(call_db, "create_partner", partner)
    if not ok then
        logger.error("Failed to create partner: %s", result)
        return false
    end
    
    return result
end

-- 批量创建伙伴
function M.batch_create_partners(partners)
    if not partners or #partners == 0 then
        logger.error("batch_create_partners: invalid partners data")
        return false
    end
    
    local ok, result = pcall(call_db, "batch_create_partners", partners)
    if not ok then
        logger.error("Failed to batch create partners: %s", result)
        return false
    end
    
    return true, result
end

-- 更新伙伴
function M.update_partner(partner)
    if not partner or not partner.id then
        logger.error("update_partner: invalid partner data")
        return false
    end
    
    local ok, result = pcall(call_db, "update_partner", partner)
    if not ok then
        logger.error("Failed to update partner: %s", result)
        return false
    end
    
    return result
end

-- 删除伙伴
function M.delete_partner(partner_id)
    if not partner_id then
        logger.error("delete_partner: partner_id is nil")
        return false
    end
    
    local ok, result = pcall(call_db, "delete_partner", partner_id)
    if not ok then
        logger.error("Failed to delete partner: %s", result)
        return false
    end
    
    return result
end

-- 记录伙伴变化
function M.log_partner_change(log_data)
    -- 参数验证
    if not log_data then
        logger.error("log_partner_change: log_data is nil")
        return false
    end
    
    if not log_data.user_id then
        logger.error("log_partner_change: missing user_id")
        return false
    end
    
    if not log_data.partner_id then
        logger.error("log_partner_change: missing partner_id")
        return false
    end
    
    if not log_data.change_type then
        logger.error("log_partner_change: missing change_type")
        return false
    end

    -- 确保所有字段都是正确的类型
    local data = {
        user_id = tonumber(log_data.user_id),
        partner_id = tonumber(log_data.partner_id),
        change_type = tostring(log_data.change_type),
        old_value = tostring(log_data.old_value or ""),
        new_value = tostring(log_data.new_value or ""),
        change_time = tonumber(log_data.change_time or os.time()),
        extra_info = tostring(log_data.extra_info or "")
    }

    -- 记录详细日志
    logger.debug("Logging partner change: %s", utils.table_to_string(data))
    
    -- 调用数据库服务
    local ok, result = pcall(call_db, "log_partner_change", data)
    if not ok then
        logger.error("Failed to log partner change: %s", result)
        return false
    end
    
    return result
end

-- 地图相关数据库操作
-- 获取用户大富翁状态
function M.get_user_monopoly_state(user_id)
    if not user_id then
        logger.error("db_client.get_user_monopoly_state: missing user_id")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_user_monopoly_state", user_id)
    if not ok then
        logger.error("Failed to get monopoly state: %s", result)
        return nil
    end
    
    return result
end

-- 创建用户大富翁状态
function M.create_monopoly_state(state_data)
    if not state_data or not state_data.user_id then
        logger.error("db_client.create_monopoly_state: invalid state data")
        return false
    end
    
    local ok, result = pcall(call_db, "create_monopoly_state", state_data)
    if not ok then
        logger.error("Failed to create monopoly state: %s", result)
        return false
    end
    
    return true
end

-- 更新用户大富翁状态
function M.update_monopoly_state(state_data)
    if not state_data or not state_data.user_id then
        logger.error("db_client.update_monopoly_state: invalid state data")
        return false
    end
    
    local ok, result = pcall(call_db, "update_monopoly_state", state_data)
    if not ok then
        logger.error("Failed to update monopoly state: %s", result)
        return false
    end
    
    return true
end

-- 获取章节进度
function M.get_chapter_progress(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("db_client.get_chapter_progress: invalid params")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_chapter_progress", {
        user_id = user_id,
        chapter_id = chapter_id
    })
    if not ok then
        logger.error("Failed to get chapter progress: %s", result)
        return nil
    end
    
    return result
end

-- 创建章节进度
function M.create_chapter_progress(progress_data)
    if not progress_data or not progress_data.user_id or not progress_data.chapter_id then
        logger.error("db_client.create_chapter_progress: invalid progress data")
        return false
    end
    
    local ok, result = pcall(call_db, "create_chapter_progress", progress_data)
    if not ok then
        logger.error("Failed to create chapter progress: %s", result)
        return false
    end
    
    return true
end

-- 更新章节进度
function M.update_chapter_progress(progress_data)
    if not progress_data or not progress_data.user_id or not progress_data.chapter_id then
        logger.error("db_client.update_chapter_progress: invalid progress data")
        return false
    end
    
    local ok, result = pcall(call_db, "update_chapter_progress", progress_data)
    if not ok then
        logger.error("Failed to update chapter progress: %s", result)
        return false
    end
    
    return true
end

-- 获取大富翁事件
function M.get_monopoly_events(params)
    if not params or not params.chapter_id or not params.cell_id then
        logger.error("db_client.get_monopoly_events: invalid params")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_monopoly_events", params)
    if not ok then
        logger.error("Failed to get monopoly events: %s", result)
        return nil
    end
    
    return result
end

-- 创建大富翁事件
function M.create_monopoly_event(event_data)
    if not event_data or not event_data.chapter_id or
       not event_data.cell_id then
        logger.error("db_client.create_monopoly_event: invalid event data")
        return false
    end
    
    local ok, result = pcall(call_db, "create_monopoly_event", event_data)
    if not ok then
        logger.error("Failed to create monopoly event: %s", result)
        return false
    end
    
    return true
end

-- 更新大富翁事件状态
function M.update_monopoly_event_status(event_id, status, complete_time)
    if not event_id then
        logger.error("db_client.update_monopoly_event_status: invalid event_id")
        return false
    end
    
    local ok, result = pcall(call_db, "update_monopoly_event_status", {
        id = event_id,
        status = status,
        complete_time = complete_time or 0
    })
    if not ok then
        logger.error("Failed to update monopoly event status: %s", result)
        return false
    end
    
    return true
end

-- 记录大富翁操作日志
function M.create_monopoly_log(log_data)
    if not log_data or not log_data.user_id or not log_data.chapter_id or not log_data.operation_type then
        logger.error("db_client.create_monopoly_log: invalid log data")
        return false
    end
    
    local ok, result = pcall(call_db, "create_monopoly_log", log_data)
    if not ok then
        logger.error("Failed to create monopoly log: %s", result)
        return false
    end
    
    return true
end

-- 获取大富翁事件详情
function M.get_monopoly_event(event_id)
    if not event_id then
        logger.error("db_client.get_monopoly_event: invalid event_id")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_monopoly_event", event_id)
    if not ok then
        logger.error("Failed to get monopoly event: %s", result)
        return nil
    end
    
    return result
end

-- 创建随机事件
function M.create_monopoly_random_event(event_data)
    if not event_data or not event_data.user_id or not event_data.chapter_id 
        or not event_data.event_id or not event_data.cell_id then
        logger.error("create_monopoly_random_event: invalid event data")
        return false
    end
    
    local current_time = os.time()
    
    -- 构建数据库记录
    local db_event = {
        user_id = event_data.user_id,
        chapter_id = event_data.chapter_id,
        event_id = event_data.event_id,
        cell_id = event_data.cell_id,
        create_time = event_data.create_time or current_time,
        update_time = event_data.update_time or current_time
    }
    
    local ok, result = pcall(call_db, "create_monopoly_random_event", db_event)
    if not ok then
        logger.error("Failed to create monopoly random event: %s", result)
        return false
    end
    
    return result
end

-- 统计用户特定随机事件的数量
function M.count_monopoly_random_events(user_id, chapter_id, event_id)
    if not user_id or not chapter_id or not event_id then
        logger.error("count_monopoly_random_events: invalid parameters")
        return 0
    end
    
    local ok, result = pcall(call_db, "count_monopoly_random_events", user_id, chapter_id, event_id)
    if not ok then
        logger.error("Failed to count monopoly random events: %s", result)
        return 0
    end
    
    return result or 0
end

-- 获取已占用的格子
function M.get_occupied_cells(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("get_occupied_cells: invalid parameters")
        return {}
    end
    
    local ok, result = pcall(call_db, "get_occupied_cells", user_id, chapter_id)
    if not ok then
        logger.error("Failed to get occupied cells: %s", result)
        return {}
    end
    
    return result or {}
end

-- 获取用户随机事件
function M.get_monopoly_random_events(user_id, chapter_id)
    if not user_id or not chapter_id then
        logger.error("get_monopoly_random_events: invalid parameters")
        return {}
    end
    
    local ok, result = pcall(call_db, "get_monopoly_random_events", user_id, chapter_id)
    if not ok then
        logger.error("Failed to get monopoly random events: %s", result)
        return {}
    end
    
    return result or {}
end

-- 获取用户通过的章节
function M.get_user_passed_chapters(user_id)
    if not user_id then
        logger.error("get_user_passed_chapters: invalid user_id")
        return {}
    end

    local ok, result = pcall(call_db, "get_user_passed_chapters", user_id)
    if not ok then
        logger.error("Failed to get user passed chapters: %s", result)
        return {}
    end

    return result or {}
end 


return M 