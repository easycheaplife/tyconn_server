local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

skynet.start(function()
    local node_name = skynet.getenv("node_name")
    
    -- 初始化节点
    local env = cluster_util.init_node(node_name)
    
    -- 启动数据库代理服务
    local db_service = skynet.newservice("db_proxy/server")
    
    -- 注册服务
    cluster.register(node_name, db_service)
    logger.info("DB service registered as %s with handle %s", node_name, tostring(db_service))
    
    -- 打开集群端口
    cluster.open(node_name)
end) 