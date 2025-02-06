include "../config/path.lua"

thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/game"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "game2"

-- JWT配置
jwt_secret = "your_jwt_secret_key"  -- 与登录服务器相同的密钥
jwt_expire = 3600

-- 日志配置
LOG_LEVEL = 1

heartbeat_timeout = 180  -- 与 game1.lua 保持一致