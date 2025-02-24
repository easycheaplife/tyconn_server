local logger = require "logger"
local user_model = require "db_proxy.models.user_model"
local token_model = require "db_proxy.models.token_model"
local card_model = require "db_proxy.models.card_model"
local item_model = require "db_proxy.models.item_model"
local bag_model = require "db_proxy.models.bag_model"

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

return CMD 