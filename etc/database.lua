-- 数据库配置
local database = {
    -- MySQL配置 (完整迁移自 etc/config/mysql.lua)
    mysql = {
        -- 从环境变量读取数据库密码
        connection = {
            host = os.getenv("MYSQL_HOST") or "127.0.0.1",
            port = 3306,
            user = os.getenv("MYSQL_USER") or "root",
            password = os.getenv("MYSQL_PASSWORD") or "123456",
            charset = "utf8mb4",
            max_packet_size = 1024 * 1024,
            auth = "mysql_native_password"  -- 使用旧的认证方式
        },
        
        -- 数据库名称
        database = os.getenv("MYSQL_DATABASE") or "tyconn",
        
        -- 重试配置
        retry = {
            max_attempts = 3,
            delay = 1  -- 秒
        },
        
        -- 连接池配置
        pool = {
            max_connections = 5,
            idle_timeout = 60  -- 秒
        }
    },

    -- Redis配置
    redis = {
        -- 基础配置
        host = "127.0.0.1",
        port = 6379,
        db = 0,
        -- auth = "your_password",  -- 如果需要密码认证

        -- 连接池配置
        pool_size = 8,
        max_packet_size = 1024 * 1024,

        -- 缓存过期时间(秒)
        expire = {
            token = 3600,      -- token缓存1小时
            user = 1800,       -- 用户信息缓存30分钟
            card = 1800,       -- 卡牌信息缓存30分钟
        },

        -- 缓存key前缀
        prefix = {
            token = "token",   -- token缓存前缀
            user = "user",     -- 用户信息缓存前缀
            card = "card",     -- 卡牌信息缓存前缀
        }
    }
}

return database 