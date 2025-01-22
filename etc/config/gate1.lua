include "../config/path.lua"

thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/gate"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "gate1"

-- WebSocket配置
websocket_host = "127.0.0.1"
websocket_port = 8022

-- 节点选择配置
-- round_robin: 均匀分配负载
-- connection_hash: 相同连接总是连到同一服务器
node_selector = "connection_hash"

-- 日志配置
LOG_LEVEL = 1