local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 创建缓存对象
local cache = {
    user_cards = {},  -- 用户卡牌缓存
    expire_time = 300  -- 缓存过期时间(秒)
}

-- 获取用户卡牌缓存
function M.get_user_cards(user_id)
    local data = cache.user_cards[user_id]
    if data and os.time() - data.time < cache.expire_time then
        return data.cards
    end
    return nil
end

-- 设置用户卡牌缓存
function M.set_user_cards(user_id, cards)
    cache.user_cards[user_id] = {
        cards = cards,
        time = os.time()
    }
end

-- 移除用户卡牌缓存
function M.remove_user_cards(user_id)
    cache.user_cards[user_id] = nil
end

-- 清理过期缓存
function M.cleanup()
    local now = os.time()
    for user_id, data in pairs(cache.user_cards) do
        if now - data.time >= cache.expire_time then
            cache.user_cards[user_id] = nil
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