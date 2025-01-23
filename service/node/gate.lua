local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

skynet.start(function()
    local node_name = skynet.getenv("node_name")
    local ws_host = skynet.getenv("websocket_host")
    local ws_port = skynet.getenv("websocket_port")
    
    -- 打印环境变量
    logger.debug("Environment variables:")
    logger.debug("  node_name = %s", node_name)
    logger.debug("  websocket_host = %s", ws_host)
    logger.debug("  websocket_port = %s", ws_port)
    
    -- 初始化节点
    local env = cluster_util.init_node(node_name)
    
    -- 查找所有game节点
    local game_nodes = {}  -- 改名更清晰
    for node, addr in pairs(env) do
        if type(node) == "string" and node:match("^game") then
            table.insert(game_nodes, node)  -- 只需要存储节点名
            logger.info("Found game node: %s at %s", node, addr)
        end
    end
    
    if #game_nodes == 0 then
        error("No game nodes found in cluster configuration")
    end
    
    -- 启动网关管理器
    local gateway_manager = skynet.newservice("gate/manager")
    local port = tonumber(skynet.getenv("websocket_port"))
    
    local ok = skynet.call(gateway_manager, "lua", "start", {
        port = port,
        game_nodes = game_nodes  -- 只传递节点名列表
    })
    
    if not ok then
        error("Failed to start gateway manager")
    end
    
    -- 打开集群端口
    cluster.open(node_name)
end)