local logger = require "logger"
local user_model = require "db_proxy.models.user_model"
local token_model = require "db_proxy.models.token_model"
local card_model = require "db_proxy.models.card_model"
local item_model = require "db_proxy.models.item_model"
local bag_model = require "db_proxy.models.bag_model"
local ping_handler = require "db_proxy.handlers.ping_handler"
local equipment_model = require "db_proxy.models.equipment_model"
local mail_model = require "db_proxy.models.mail_model"
local partner_model = require "db_proxy.models.partner_model"
local monopoly_model = require "db_proxy.models.monopoly_model"

local CMD = {}

-- 包装错误处理
local function wrap_call(func, ...)
    local ok, result, err = pcall(func, ...)
    if not ok then
        logger.error("Call failed: %s", result)
        return false, "Internal error"
    end
    return result, err
end

-- 添加 ping 命令
function CMD.ping(node_name)
    return wrap_call(ping_handler.ping, node_name)
end

-- 用户相关操作
function CMD.create_user(user)
    return wrap_call(user_model.create_user, user)
end

function CMD.get_user(account)
    return wrap_call(user_model.get_user, account)
end

function CMD.get_user_info(user_id)
    return wrap_call(user_model.get_user_info, user_id)
end

function CMD.update_user(user)
    return wrap_call(user_model.update_user, user)
end

-- 添加更新用户登录时间的命令
function CMD.update_user_login_time(args)
    return wrap_call(user_model.update_user_login_time, args)
end

-- Token相关操作
function CMD.sync_jwt(token_info)
    return wrap_call(token_model.sync_token, token_info)
end

function CMD.verify_jwt(account, token)
    return wrap_call(token_model.verify_token, account, token)
end

function CMD.renew_jwt(account, token, expire_time)
    return wrap_call(token_model.renew_token, account, token, expire_time)
end

-- 卡牌相关命令
function CMD.create_card(card)
    return wrap_call(card_model.create_card, card)
end

function CMD.batch_create_cards(cards)
    return wrap_call(card_model.batch_create_cards, cards)
end

function CMD.get_user_cards(user_id)
    return wrap_call(card_model.get_user_cards, user_id)
end

function CMD.update_card(card_info)
    return wrap_call(card_model.update_card, card_info)
end

-- 物品相关命令
function CMD.get_user_items(user_id)
    return wrap_call(item_model.get_user_items, user_id)
end

function CMD.update_user_items(user_id, items)
    -- 验证物品数据的完整性
    if items then
        for _, item in ipairs(items) do
            if not item.id or not item.item_id or not item.count then
                logger.error("Invalid item data: %s", utils.table_to_string(item))
                return false, "Invalid item data"
            end
        end
    end
    return wrap_call(item_model.update_user_items, user_id, items)
end

function CMD.log_item_change(log)
    return wrap_call(item_model.log_item_change, log)
end

-- 更新单个物品
function CMD.update_single_item(item)
    -- 验证物品数据的完整性
    if not item or not item.id or not item.user_id or not item.count then
        logger.error("Invalid item data for update_single_item")
        return false, "Invalid item data"
    end
    return wrap_call(item_model.update_single_item, item)
end

-- 添加单个物品
function CMD.add_single_item(item)
    -- 验证物品数据的完整性
    if not item or not item.id or not item.user_id or not item.item_id or not item.count then
        logger.error("Invalid item data for add_single_item")
        return false, "Invalid item data"
    end
    return wrap_call(item_model.add_single_item, item)
end

-- 删除单个物品
function CMD.delete_single_item(params)
    -- 验证参数完整性
    if not params or not params.id or not params.user_id then
        logger.error("Invalid params for delete_single_item")
        return false, "Invalid parameters"
    end
    return wrap_call(item_model.delete_single_item, params)
end

-- 背包相关命令
function CMD.get_user_bag(user_id, bag_type)
    return wrap_call(bag_model.get_user_bag, user_id, bag_type)
end

function CMD.create_user_bag(params)
    return wrap_call(bag_model.create_user_bag, params)
end

function CMD.batch_create_slots(slots)
    return wrap_call(bag_model.batch_create_slots, slots)
end

function CMD.delete_user_bag(user_id, bag_type)
    return wrap_call(bag_model.delete_user_bag, user_id, bag_type)
end

function CMD.update_slot_state(params)
    return wrap_call(bag_model.update_slot_state, params)
end

function CMD.update_bag_size(params)
    return wrap_call(bag_model.update_bag_size, params)
end

function CMD.get_bag_slots(user_id, bag_type)
    return wrap_call(bag_model.get_bag_slots, user_id, bag_type)
end

function CMD.get_user_bags(user_id)
    return wrap_call(bag_model.get_user_bags, user_id)
end

-- 装备相关命令
function CMD.check_equip_slots_exist(user_id)
    return wrap_call(equipment_model.check_equip_slots_exist, user_id)
end

function CMD.get_equip_slots(user_id)
    return wrap_call(equipment_model.get_equip_slots, user_id)
end

function CMD.get_equip_level(user_id)
    return wrap_call(equipment_model.get_equip_level, user_id)
end

function CMD.update_equip_slot(params)
    return wrap_call(equipment_model.update_equip_slot, params)
end

function CMD.update_equip_level(params)
    return wrap_call(equipment_model.update_equip_level, params)
end

function CMD.init_equip_slots(params)
    return wrap_call(equipment_model.init_equip_slots, params)
end

function CMD.init_equip_level(params)
    return wrap_call(equipment_model.init_equip_level, params)
end

function CMD.get_completed_equip_upgrades(current_time)
    return wrap_call(equipment_model.get_completed_equip_upgrades, current_time)
end

function CMD.get_expired_equipment(params)
    return wrap_call(equipment_model.get_expired_equipment, params)
end

-- 邮件相关命令
function CMD.get_user_mails(user_id)
    return wrap_call(mail_model.get_user_mails, user_id)
end

function CMD.get_mail(params)
    return wrap_call(mail_model.get_mail, params)
end

function CMD.save_mail(mail)
    return wrap_call(mail_model.save_mail, mail)
end

function CMD.save_mail_template(template)
    return wrap_call(mail_model.save_mail_template, template)
end

function CMD.update_mail_status(params)
    return wrap_call(mail_model.update_mail_status, params)
end

function CMD.batch_update_mail_status(params)
    return wrap_call(mail_model.batch_update_mail_status, params)
end

function CMD.delete_mails(params)
    return wrap_call(mail_model.delete_mails, params)
end

function CMD.delete_expired_mails(current_time)
    return wrap_call(mail_model.delete_expired_mails, current_time)
end

function CMD.get_mail_template(template_id)
    return wrap_call(mail_model.get_mail_template, template_id)
end

function CMD.get_valid_mail_templates(current_time)
    return wrap_call(mail_model.get_valid_mail_templates, current_time)
end

-- 伙伴相关命令
function CMD.create_partner(partner)
    return wrap_call(partner_model.create_partner, partner)
end

function CMD.batch_create_partners(partners)
    return wrap_call(partner_model.batch_create_partners, partners)
end

function CMD.get_user_partners(user_id)
    return wrap_call(partner_model.get_user_partners, user_id)
end

function CMD.get_partner(partner_id)
    return wrap_call(partner_model.get_partner, partner_id)
end

function CMD.update_partner(partner)
    return wrap_call(partner_model.update_partner, partner)
end

function CMD.delete_partner(params)
    return wrap_call(partner_model.delete_partner, params.partner_id, params.user_id)
end

function CMD.check_partner_exists(params)
    return wrap_call(partner_model.check_partner_exists, params.user_id, params.unit_id)
end

function CMD.log_partner_change(log)
    return wrap_call(partner_model.log_partner_change, log)
end

-- 大富翁相关命令
function CMD.get_user_monopoly_state(user_id)
    return wrap_call(monopoly_model.get_user_monopoly_state, user_id)
end

function CMD.create_monopoly_state(state_data)
    return wrap_call(monopoly_model.create_monopoly_state, state_data)
end

function CMD.update_monopoly_state(state_data)
    return wrap_call(monopoly_model.update_monopoly_state, state_data)
end

function CMD.get_chapter_progress(params)
    return wrap_call(monopoly_model.get_chapter_progress, params)
end

function CMD.create_chapter_progress(progress_data)
    return wrap_call(monopoly_model.create_chapter_progress, progress_data)
end

function CMD.update_chapter_progress(progress_data)
    return wrap_call(monopoly_model.update_chapter_progress, progress_data)
end

function CMD.get_monopoly_events(params)
    return wrap_call(monopoly_model.get_monopoly_events, params)
end

function CMD.get_monopoly_event(event_id)
    return wrap_call(monopoly_model.get_monopoly_event, event_id)
end

function CMD.create_monopoly_event(event_data)
    return wrap_call(monopoly_model.create_monopoly_event, event_data)
end

function CMD.update_monopoly_event_status(params)
    return wrap_call(monopoly_model.update_monopoly_event_status, params)
end

function CMD.create_monopoly_log(log_data)
    return wrap_call(monopoly_model.create_monopoly_log, log_data)
end

return CMD