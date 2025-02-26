local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

local M = {}

-- 存储不同服务类型的节点列表
local service_nodes = {}
local current_indices = {}
local initialized = {}

-- 初始化指定服务类型的节点列表
function M.init(service_type)
    if initialized[service_type] then
        return true
    end

    -- 从cluster配置中获取指定前缀的节点
    local nodes = cluster_util.get_nodes_by_prefix(service_type)
    service_nodes[service_type] = nodes
    current_indices[service_type] = 1
    
    if #nodes == 0 then
        logger.error("No %s nodes found in cluster config", service_type)
        return false
    end
    
    logger.info("%s balancer initialized with %d nodes: %s", 
        service_type, #nodes, table.concat(nodes, ", "))
    
    initialized[service_type] = true
    return true
end

-- 获取下一个节点（轮询方式）
function M.get_node(service_type)
    if not initialized[service_type] then
        if not M.init(service_type) then
            return service_type.."1"  -- 默认返回
        end
    end
    
    local nodes = service_nodes[service_type]
    if #nodes == 0 then
        return service_type.."1"  -- 默认返回
    end
    
    -- 轮询选择下一个节点
    local index = current_indices[service_type]
    current_indices[service_type] = (index % #nodes) + 1
    return nodes[index]
end

-- 获取所有节点
function M.get_all_nodes(service_type)
    if not initialized[service_type] then
        M.init(service_type)
    end
    return service_nodes[service_type] or {}
end

-- 广播到所有节点
function M.broadcast(service_type, cmd, ...)
    if not initialized[service_type] then
        M.init(service_type)
    end
    
    local results = {}
    local nodes = service_nodes[service_type] or {}
    for _, node in ipairs(nodes) do
        -- 使用 @node 作为服务名，因为是跨节点调用
        logger.info("broadcast %s to %s", service_type, node)
        local ok, result = pcall(cluster.call, node, "@"..node, cmd, ...)
        if not ok then
            logger.error("Failed to call %s node %s: %s", service_type, node, result)
        else
            results[node] = result
        end
    end
    
    return results
end

-- 重新加载节点列表
function M.reload(service_type)
    service_nodes[service_type] = {}
    current_indices[service_type] = 1
    initialized[service_type] = false
    return M.init(service_type)
end

return M 