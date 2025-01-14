local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

skynet.start(function()
    local node_name = skynet.getenv("node_name")
    local game_node = skynet.getenv("game_node")
    
    -- 初始化节点
    local env = cluster_util.init_node(node_name)
    
    -- 创建游戏服务代理
    local game_service = cluster.proxy(game_node, game_node)
    
    -- 启动网关管理器
    local gateway_manager = skynet.newservice("gate/manager")
    local port = tonumber(skynet.getenv("websocket_port")) or 8008
    
    local ok = skynet.call(gateway_manager, "lua", "start", {
        port = port,
        game = game_service,
        game_node = game_node
    })
    
    -- 打开集群端口
    cluster.open(node_name)
end)