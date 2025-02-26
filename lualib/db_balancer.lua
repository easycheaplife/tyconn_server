local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local cluster_util = require "cluster_util"

local M = {}

local db_proxies = {}
local current_index = 1
local initialized = false

-- 初始化db_proxy列表
function M.init()
    if initialized then
        return true
    end

    -- 从cluster配置中获取所有db_proxy节点
    local nodes = cluster_util.get_nodes_by_prefix("db_proxy")
    for _, node in ipairs(nodes) do
        table.insert(db_proxies, node)
    end
    
    if #db_proxies == 0 then
        logger.error("No db_proxy nodes found in cluster config")
        return false
    end
    
    logger.info("DB balancer initialized with %d nodes: %s", 
        #db_proxies, table.concat(db_proxies, ", "))
    
    initialized = true
    return true
end

-- 轮询方式获取下一个db_proxy
function M.get_db_proxy()
    if not initialized then
        if not M.init() then
            return "db_proxy1"  -- 默认返回
        end
    end
    
    if #db_proxies == 0 then
        return "db_proxy1"  -- 默认返回
    end
    
    -- 轮询选择下一个节点
    current_index = (current_index % #db_proxies) + 1
    return db_proxies[current_index]
end

-- 获取所有db_proxy节点
function M.get_all_proxies()
    if not initialized then
        M.init()
    end
    return db_proxies
end

-- 重新加载节点列表
function M.reload()
    db_proxies = {}
    initialized = false
    return M.init()
end

return M 