local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

skynet.start(function()
    local node_name = skynet.getenv("node_name")
    
    -- 初始化节点
    local env = cluster_util.init_node(node_name)
    
    -- 启动登录服务
    local login_server = skynet.newservice("login/server")
    local ok = skynet.call(login_server, "lua", "start", {
        port = tonumber(skynet.getenv("websocket_port")),
        jwt_secret = skynet.getenv("jwt_secret"),
        jwt_expire = tonumber(skynet.getenv("jwt_expire"))
    })
    
    if not ok then
        error("Failed to start login server")
    end
    
    -- 注册集群服务
    cluster.register(node_name, login_server)
    logger.info("Login service registered as %s with handle %s", node_name, tostring(login_server))
    
    -- 打开集群端口
    cluster.open(node_name)
end) 