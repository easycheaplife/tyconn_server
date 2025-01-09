include "../config/path.lua"

thread = 8
harbor = 0
address = "127.0.0.1:2003"

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/gate"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "gate1"
game_node = "game1"
websocket_port = 8891

-- 日志配置
LOG_LEVEL = 1