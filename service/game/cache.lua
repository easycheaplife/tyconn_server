local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 创建缓存对象
local cache = {
    user_cards = {},  -- 用户卡牌缓存 user_id -> {cards, time}
    user_info = {},   -- 用户信息缓存 account -> {user, time}
    expire_time = 300 -- 缓存过期时间(秒)
}

-- 卡牌缓存
function M.get_user_cards(user_id)
    local data = cache.user_cards[user_id]
    if data and os.time() - data.time < cache.expire_time then
        return data.cards
    end
    return nil
end

function M.set_user_cards(user_id, cards)
    cache.user_cards[user_id] = {
        cards = cards,
        time = os.time()
    }
end

function M.remove_user_cards(user_id)
    cache.user_cards[user_id] = nil
end

-- 用户信息缓存
function M.get_user_info(account)
    local data = cache.user_info[account]
    if data and os.time() - data.time < cache.expire_time then
        return data.user
    end
    return nil
end

function M.set_user_info(account, user)
    cache.user_info[account] = {
        user = user,
        time = os.time()
    }
end

function M.remove_user_info(account)
    cache.user_info[account] = nil
end

-- 清理过期缓存
function M.cleanup()
    local now = os.time()
    
    -- 清理卡牌缓存
    for user_id, data in pairs(cache.user_cards) do
        if now - data.time >= cache.expire_time then
            cache.user_cards[user_id] = nil
        end
    end
    
    -- 清理用户信息缓存
    for account, data in pairs(cache.user_info) do
        if now - data.time >= cache.expire_time then
            cache.user_info[account] = nil
        end
    end
end

-- 启动定时清理
skynet.fork(function()
    while true do
        skynet.sleep(100 * 60)  -- 每100秒清理一次
        M.cleanup()
    end
end)

return M 