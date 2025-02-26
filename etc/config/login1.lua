include "../config/path.lua"

thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/login"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "login1"
websocket_port = 8021  -- 添加WebSocket端口配置

-- JWT配置
jwt_secret = "your_jwt_secret_key"  -- JWT密钥
jwt_expire = 3600                   -- JWT过期时间(秒)

-- 版本配置
version_min = "0.0.1"               -- 最低支持版本
version_latest = "1.0.0"            -- 最新版本
version_force_update = "false"      -- 是否强制更新

-- 日志配置
LOG_LEVEL = 1 