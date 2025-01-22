include "../config/path.lua"

thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/gate"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "gate2"

-- WebSocket配置
websocket_host = "127.0.0.1"
websocket_port = 8023

-- JWT配置
jwt_secret = "your_jwt_secret_key"  -- 与登录服务器相同的密钥
jwt_expire = 3600

-- 节点选择配置
-- round_robin: 均匀分配负载
-- connection_hash: 相同连接总是连到同一服务器
node_selector = "connection_hash"

-- 日志配置
LOG_LEVEL = 1