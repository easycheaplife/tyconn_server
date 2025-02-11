local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 加载各个缓存模块
M.user = require "game.cache.user_cache"
M.card = require "game.cache.card_cache"

-- 启动定时清理
skynet.fork(function()
    while true do
        skynet.sleep(100 * 60)  -- 每100秒清理一次
        M.user.cleanup()
        M.card.cleanup()
    end
end)

return M 