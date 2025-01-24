local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local cluster = require "skynet.cluster"

local M = {}
local gate_nodes = {}  -- gate_name -> gate_info
local last_selected = nil  -- 上次选择的网关
local MAX_CLIENTS = 5000  -- 单个网关最大客户端数

-- 初始化
function M.init()
    -- 定期打印网关状态
    skynet.fork(function()
        while true do
            M.print_status()
            skynet.sleep(1000)  -- 每10秒打印一次
        end
    end)
    
    -- 定期清理超时的网关
    skynet.fork(function()
        while true do
            M.cleanup_timeout(120)  -- 120秒超时
            skynet.sleep(100)
        end
    end)
    
    return true
end

-- 打印网关状态
function M.print_status()
    local total = 0
    local ready = 0
    local clients = 0
    
    for name, info in pairs(gate_nodes) do
        total = total + 1
        if info.available then
            ready = ready + 1
            clients = clients + (info.client_count or 0)
            logger.debug("Gate %s: clients=%d/%d (%.1f%%), uptime=%ds",
                name,
                info.client_count or 0,
                MAX_CLIENTS,
                ((info.client_count or 0) / MAX_CLIENTS) * 100,
                os.time() - info.startup_time)
        end
    end
    
    if total > 0 then
        logger.info("Total: %d/%d gates ready, %d clients", ready, total, clients)
    end
end

-- 更新网关状态
function M.update_status(status_data)
    if not status_data then
        logger.error("Received nil status data")
        return false
    end
    
    local ok, status = pcall(pb.decode, "internal.ServiceStatus", status_data)
    if not ok then
        logger.error("Failed to decode gate status: %s", status)
        return false
    end
    
    -- 更新网关信息
    gate_nodes[status.node_name] = {
        host = status.host,
        port = status.port,
        client_count = status.client_count or 0,
        last_update = os.time(),
        available = true,
        startup_time = gate_nodes[status.node_name] and 
                      gate_nodes[status.node_name].startup_time or os.time(),
        load = (status.client_count or 0) / MAX_CLIENTS
    }
    
    return true
end

-- 清理超时的网关
function M.cleanup_timeout(timeout)
    local now = os.time()
    for name, info in pairs(gate_nodes) do
        if now - info.last_update > timeout then
            logger.warn("Gate %s timeout, marking as unavailable", name)
            info.available = false
        end
    end
end

-- 选择网关服务器
function M.select_server()
    local available_gates = {}
    local total = 0
    local ready = 0
    
    for name, info in pairs(gate_nodes) do
        total = total + 1
        if info.available and info.load < 0.9 then
            ready = ready + 1
            table.insert(available_gates, {
                name = name,
                load = info.load
            })
        end
    end
    
    if #available_gates == 0 then
        logger.error("No available gates (total=%d, ready=%d)", total, ready)
        return nil
    end
    
    -- 按负载排序
    table.sort(available_gates, function(a, b)
        return a.load < b.load
    end)
    
    -- 选择负载最低的网关
    local selected = available_gates[1].name
    if #available_gates > 1 and selected == last_selected then
        selected = available_gates[2].name
    end
    last_selected = selected
    
    return selected
end

-- 获取网关地址
function M.get_addr(gate_node)
    if not gate_node then
        logger.error("Gate node is nil")
        return nil
    end
    
    local gate_info = gate_nodes[gate_node]
    if not gate_info then
        logger.error("Gate %s not found", gate_node)
        return nil
    end
    
    return {
        host = gate_info.host,
        port = gate_info.port
    }
end

return M 