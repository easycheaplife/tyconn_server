include "../config/path.lua"

thread = 8
harbor = 0
address = "127.0.0.1:4001"

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/db_proxy"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "db_proxy"

-- 日志配置
LOG_LEVEL = 1 