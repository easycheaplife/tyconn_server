local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local utils = require "utils"

local M = {}

-- 调用数据库服务
local function call_db(...)
    return cluster.call("db_proxy", "@db_proxy", ...)
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

-- 记录物品变化
function M.log_item_change(user_id, item_id, count, type, source, before_count, after_count)
    return call_db("log_item_change", {
        user_id = user_id,
        item_id = item_id,
        count = count,
        type = type,
        source = source,
        before_count = before_count,
        after_count = after_count,
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

return M 