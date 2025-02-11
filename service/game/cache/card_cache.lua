local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 卡牌缓存
local cache = {
    data = {},  -- user_id -> {cards, time}
    expire_time = 300 -- 缓存过期时间(秒)
}

function M.get(user_id)
    local data = cache.data[user_id]
    if data and os.time() - data.time < cache.expire_time then
        return data.cards
    end
    return nil
end

function M.set(user_id, cards)
    cache.data[user_id] = {
        cards = cards,
        time = os.time()
    }
end

function M.remove(user_id)
    cache.data[user_id] = nil
end

-- 清理过期缓存
function M.cleanup()
    local now = os.time()
    for user_id, data in pairs(cache.data) do
        if now - data.time >= cache.expire_time then
            cache.data[user_id] = nil
        end
    end
end

return M 