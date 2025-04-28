local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

local M = {}

-- 存储不同服务类型的节点列表
local service_nodes = {}
local current_indices = {}
local initialized = {}
local node_status = {} -- 记录节点状态
local check_interval = 10 -- 健康检查间隔(秒)

-- 节点状态
local NODE_STATUS = {
    HEALTHY = 1,    -- 健康
    UNHEALTHY = 2,  -- 不健康
    REMOVED = 3     -- 已摘除
}

-- 健康检查
local function check_node_health(node, caller_node)
    -- 对于 db_proxy 服务，调用其 ping 接口
    if string.find(node, "db_proxy") then
        -- 使用 pcall 包装 cluster.call 以处理可能的错误
        local ok, result = pcall(cluster.call, node, "@"..node, "ping", caller_node)
        if not ok then
            logger.error("Failed to ping db_proxy node %s: %s", node, result)
            return false
        end
        -- 检查 ping 的返回结果
        if not result then
            logger.error("Ping returned false from node %s", node)
            return false
        end
        return true
    end
    return true
end

-- 更新节点状态
local function update_node_status(service_type, node, status)
    if not node_status[service_type] then
        node_status[service_type] = {}
    end
    
    local old_status = node_status[service_type][node]
    node_status[service_type][node] = status
    
    if old_status ~= status then
        logger.info("Node %s status changed: %d -> %d", node, old_status or 0, status)
        
        -- 如果节点恢复，重新加入可用列表
        if status == NODE_STATUS.HEALTHY and old_status == NODE_STATUS.UNHEALTHY then
            logger.info("Node %s recovered, adding back to service list", node)
        end
        
        -- 如果节点不健康，从可用列表中移除
        if status == NODE_STATUS.UNHEALTHY and old_status == NODE_STATUS.HEALTHY then
            logger.warn("Node %s became unhealthy, removing from service list", node)
        end
    end
end

-- 获取健康节点列表
local function get_healthy_nodes(service_type)
    local healthy_nodes = {}
    local nodes = service_nodes[service_type] or {}
    local status = node_status[service_type] or {}
    
    for _, node in ipairs(nodes) do
        if status[node] == NODE_STATUS.HEALTHY then
            table.insert(healthy_nodes, node)
        end
    end
    
    return healthy_nodes
end

-- 初始化指定服务类型的节点列表
function M.init(service_type, caller_node)
    if initialized[service_type] then
        return true
    end

    -- 从cluster配置中获取指定前缀的节点
    local nodes = cluster_util.get_nodes_by_prefix(service_type)
    service_nodes[service_type] = nodes
    current_indices[service_type] = 1
    node_status[service_type] = {}
    
    if #nodes == 0 then
        logger.error("No %s nodes found in cluster config", service_type)
        return false
    end
    
    -- 初始化节点状态
    for _, node in ipairs(nodes) do
        local is_healthy = check_node_health(node, caller_node)
        update_node_status(service_type, node, 
            is_healthy and NODE_STATUS.HEALTHY or NODE_STATUS.UNHEALTHY)
    end
    
    logger.info("%s balancer initialized with %d nodes: %s", 
        service_type, #nodes, table.concat(nodes, ", "))
    
    -- 启动定时健康检查
    skynet.fork(function()
        while true do
            for _, node in ipairs(nodes) do
                local is_healthy = check_node_health(node, caller_node)
                update_node_status(service_type, node,
                    is_healthy and NODE_STATUS.HEALTHY or NODE_STATUS.UNHEALTHY)
            end
            skynet.sleep(check_interval * 100)
        end
    end)
    
    initialized[service_type] = true
    return true
end

-- 获取下一个节点（轮询方式）
function M.get_node(service_type, caller_node)
    if not initialized[service_type] then
        M.init(service_type)
    end

    -- 获取健康节点列表
    local healthy_nodes = get_healthy_nodes(service_type)
    if not healthy_nodes or #healthy_nodes == 0 then
        -- 如果没有健康节点，重新检查所有节点
        logger.warn("No healthy nodes found for %s, rechecking all nodes...", service_type)
        for _, node in ipairs(service_nodes[service_type] or {}) do
            local is_healthy = check_node_health(node, caller_node or "unknown")
            update_node_status(service_type, node, 
                is_healthy and NODE_STATUS.HEALTHY or NODE_STATUS.UNHEALTHY)
        end
        -- 再次获取健康节点
        healthy_nodes = get_healthy_nodes(service_type)
        if not healthy_nodes or #healthy_nodes == 0 then
            logger.error("Still no healthy nodes available for %s", service_type)
            return nil
        end
    end

    -- 使用轮询方式选择节点
    local index = current_indices[service_type] or 1
    current_indices[service_type] = (index % #healthy_nodes) + 1
    
    local target_node = healthy_nodes[index]
    logger.debug("Selected node %s for %s", target_node, service_type)
    return target_node
end

-- 获取所有健康节点
function M.get_all_nodes(service_type)
    if not initialized[service_type] then
        M.init(service_type)
    end
    return get_healthy_nodes(service_type)
end

-- 广播到所有健康节点
function M.broadcast(service_type, caller_node, cmd, ...)
    if not initialized[service_type] then
        M.init(service_type)
    end
    
    local results = {}
    local healthy_nodes = get_healthy_nodes(service_type)
    for _, node in ipairs(healthy_nodes) do
        -- 使用 @node 作为服务名，因为是跨节点调用
        logger.info("broadcast from %s to %s", caller_node, node)
        local ok, result = pcall(cluster.call, node, "@"..node, cmd, ...)
        if not ok then
            logger.error("Failed to call from %s to %s: %s", caller_node, node, result)
            -- 更新节点状态为不健康
            update_node_status(service_type, node, NODE_STATUS.UNHEALTHY)
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
    node_status[service_type] = {}
    initialized[service_type] = false
    return M.init(service_type)
end

return M 