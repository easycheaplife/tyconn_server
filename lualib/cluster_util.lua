local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

local M = {}

-- 加载集群配置
function M.load_cluster_config()
    -- 加载集群配置
    local cluster_file = skynet.getenv("cluster")
    if not cluster_file then
        error("No cluster configuration file specified")
    end
    
    -- 创建一个新的环境来加载配置
    local env = {}
    local f, err = loadfile(cluster_file, "bt", env)
    if not f then
        error("Failed to load cluster configuration: " .. tostring(err))
    end
    
    -- 执行配置文件
    f()
    
    -- 重新加载集群配置
    cluster.reload(env)
    
    return env
end

-- 初始化节点
function M.init_node(node_name)
    -- 加载集群配置
    local env = M.load_cluster_config()
    
    -- 检查节点是否在配置中
    if not env[node_name] then
        error(string.format("Node %s not found in cluster configuration", node_name))
    end
    
    logger.info("Starting node: %s at %s", node_name, env[node_name])
    
    return env
end

return M 