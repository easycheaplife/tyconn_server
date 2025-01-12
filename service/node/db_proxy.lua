local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    -- 启动数据库代理服务
    local db_proxy = skynet.newservice("db_proxy/server")
    
    -- 注册集群节点
    cluster.open("db_proxy")
    
    -- 注册数据库代理服务
    cluster.register("db_proxy", db_proxy)
    
    skynet.exit()
end) 