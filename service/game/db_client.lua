local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

local M = {}

-- 调用数据库服务
local function call_db(cmd, ...)
    local ok, result, err = pcall(cluster.call, "db_proxy", "@db_proxy", cmd, ...)
    if not ok then
        logger.error("Failed to call db_proxy.%s: %s", cmd, result)
        return nil, result
    end
    if not result and err then
        return nil, err
    end
    return result, err
end

-- 批量创建卡牌
function M.batch_create_cards(cards)
    return call_db("batch_create_cards", cards)
end

-- 获取用户卡牌列表
function M.get_user_cards(user_id)
    return call_db("get_user_cards", user_id)
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

return M 