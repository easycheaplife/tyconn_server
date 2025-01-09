local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

skynet.start(function()
    logger.info("Gate node starting...")
    
    -- 加载集群配置
    cluster.reload {
        master = "127.0.0.1:2001",
        game = "127.0.0.1:2002",
        gate = "127.0.0.1:2003",
    }
    
    -- 等待集群准备就绪
    skynet.sleep(100)
    
    -- 获取游戏服务
    local game = cluster.proxy("game", "@game")
    
    -- 启动网关服务
    local watchdog = skynet.newservice("ws_watchdog")
    local port = tonumber(skynet.getenv("websocket_port")) or 8891
    
    -- 启动 WebSocket 网关
    local ok = skynet.call(watchdog, "lua", "start", {
        port = port,
        game = game,
        game_node = "game"
    })
    
    -- 打开集群连接
    cluster.open "gate"
    
    if ok then
        logger.info("Gate node is running on port %d", port)
    else
        logger.error("Failed to start gate node")
        skynet.exit()
    end
end)