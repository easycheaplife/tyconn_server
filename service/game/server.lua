local skynet = require "skynet"
local logger = require "logger"
local message = require "message"  -- 更新引用路径
local message_mgr = require "game.message_mgr"
local cmd_mgr = require "game.cmd_mgr"

-- 心跳相关配置
local heartbeat_timeout = tonumber(skynet.getenv("heartbeat_timeout")) or 180  -- 默认180秒超时
_G.client_heartbeats = {}  -- 记录用户最后心跳时间，全局可访问

-- 检查心跳超时
local function check_heartbeat_timeout()
    local now = os.time()
    for account, last_time in pairs(_G.client_heartbeats) do
        if now - last_time > heartbeat_timeout then
            logger.warn("User %s heartbeat timeout, disconnecting...", account)
            -- 通知网关断开用户连接
            skynet.send(".gate", "lua", "disconnect_user", account)
            _G.client_heartbeats[account] = nil
        end
    end
end

-- 服务入口
skynet.start(function()
    logger.info("Game server starting...")
    
    -- 初始化命令管理器
    if not cmd_mgr.init() then
        logger.error("Failed to initialize command manager")
        return
    end
    logger.info("Command manager initialized")
    
    -- 初始化消息处理器
    if not message_mgr.init() then
        logger.error("Failed to initialize message manager")
        return
    end
    logger.info("Message manager initialized")
    
    -- 启动心跳检查定时器
    skynet.fork(function()
        while true do
            check_heartbeat_timeout()
            skynet.sleep(100)  -- 每秒检查一次
        end
    end)
    
    logger.info("Game server started")
end)