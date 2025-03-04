local skynet = require "skynet"
local logger = require "logger"
local message = require "message"  -- 更新引用路径
local message_mgr = require "game.message_mgr"
local cmd_mgr = require "game.cmd_mgr"
local init = require "game.init"
local balancer_service = require "balancer_service"

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

-- 改名为 initialize 避免冲突
local function initialize()
    -- 加载并初始化
    local ok = init.init()
    if not ok then
        logger.error("Failed to initialize game server")
        skynet.exit()
        return false
    end
    
    logger.info("Game server starting...")
    
    -- 初始化命令管理器
    if not cmd_mgr.init() then
        logger.error("Failed to initialize command manager")
        return false
    end
    logger.info("Command manager initialized")
    
    -- 初始化消息处理器
    if not message_mgr.init() then
        logger.error("Failed to initialize message manager")
        return false
    end
    logger.info("Message manager initialized")
    
    -- 初始化service_balancer
    if not balancer_service.init("db_proxy", skynet.getenv("node_name")) then
        logger.error("Failed to initialize db_proxy balancer")
        return false
    end
    logger.info("DB proxy balancer initialized")
    
    -- 启动心跳检查定时器
    skynet.fork(function()
        while true do
            check_heartbeat_timeout()
            skynet.sleep(100)  -- 每秒检查一次
        end
    end)
    
    logger.info("Game server started")
    return true
end

-- 服务入口
skynet.start(function()
    initialize()
end)