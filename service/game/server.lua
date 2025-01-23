local skynet = require "skynet"
local logger = require "logger"
local message_mgr = require "game.message_mgr"
local cmd_mgr = require "game.cmd_mgr"

-- 心跳相关配置
local heartbeat_timeout = tonumber(skynet.getenv("heartbeat_timeout")) or 180  -- 默认180秒超时
_G.client_heartbeats = {}  -- 记录客户端最后心跳时间，全局可访问

-- 检查心跳超时
local function check_heartbeat_timeout()
    local now = os.time()
    for client_id, last_time in pairs(_G.client_heartbeats) do
        if now - last_time > heartbeat_timeout then
            logger.warn("Client %d heartbeat timeout, disconnecting...", client_id)
            handler.close(client_id)
            _G.client_heartbeats[client_id] = nil
        end
    end
end

-- 服务入口
skynet.start(function()
    logger.info("Game server starting...")
    
    -- 等待集群准备就绪
    skynet.sleep(100)  -- 等待1秒
    
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