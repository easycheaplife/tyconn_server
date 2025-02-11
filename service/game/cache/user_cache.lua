local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 用户信息缓存
local cache = {
    data = {},  -- account -> {user, time}
    expire_time = 300 -- 缓存过期时间(秒)
}

function M.get(account)
    local data = cache.data[account]
    if data and os.time() - data.time < cache.expire_time then
        return data.user
    end
    return nil
end

function M.set(account, user)
    cache.data[account] = {
        user = user,
        time = os.time()
    }
end

function M.remove(account)
    cache.data[account] = nil
end

-- 清理过期缓存
function M.cleanup()
    local now = os.time()
    for account, data in pairs(cache.data) do
        if now - data.time >= cache.expire_time then
            cache.data[account] = nil
        end
    end
end

return M 