local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

skynet.start(function()
    local node_name = skynet.getenv("node_name")
    
    -- 初始化节点
    local env = cluster_util.init_node(node_name)
    
    -- 查找所有game节点
    local game_services = {}
    for node, addr in pairs(env) do
        if type(node) == "string" and node:match("^game") then
            -- 创建游戏服务代理
            game_services[node] = cluster.proxy(node, node)
            logger.info("Connected to game node: %s at %s", node, addr)
        end
    end
    
    if not next(game_services) then
        error("No game nodes found in cluster configuration")
    end
    
    -- 启动网关管理器
    local gateway_manager = skynet.newservice("gate/manager")
    local port = tonumber(skynet.getenv("websocket_port")) or 8008
    
    local ok = skynet.call(gateway_manager, "lua", "start", {
        port = port,
        game_services = game_services  -- 传入所有游戏服务代理
    })
    
    if not ok then
        error("Failed to start gateway manager")
    end
    
    -- 打开集群端口
    cluster.open(node_name)
end)