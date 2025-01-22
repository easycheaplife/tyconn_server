local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

skynet.start(function()
    local node_name = skynet.getenv("node_name")
    local jwt_secret = skynet.getenv("jwt_secret")
    if not jwt_secret then
        error("Missing jwt_secret in environment")
    end
    
    -- 初始化节点
    local env = cluster_util.init_node(node_name)
    
    -- 启动游戏服务器
    local game_server = skynet.newservice("game/server")
    local ok = skynet.call(game_server, "lua", "start", {
        jwt_secret = jwt_secret
    })
    
    if not ok then
        error("Failed to start game server")
    end
    
    -- 注册服务
    cluster.register(node_name, game_server)
    logger.info("Game service registered as %s with handle %s", node_name, tostring(game_server))
    
    -- 打开集群端口
    cluster.open(node_name)
end)