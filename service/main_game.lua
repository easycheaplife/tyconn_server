local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

skynet.start(function()
    logger.info("Game node starting...")
    
    -- 加载集群配置
    cluster.reload {
        master = "127.0.0.1:2001",
        game = "127.0.0.1:2002",
        gate = "127.0.0.1:2003",
    }
    
    -- 启动游戏服务
    local game = skynet.newservice("game")
    
    -- 注册服务到集群
    cluster.register("game", game)
    
    -- 打开集群连接
    cluster.open "game"
    
    logger.info("Game node is running")
end)