local M = {}

-- Redis配置
M.redis = {
    host = "127.0.0.1",
    port = 6379,
    db = 0,
    auth = nil,  -- 如果需要密码验证，在这里设置
    prefix = {
        token = "token",
        user = "user",
        card = "card"
    },
    expire = {
        token = 7200,    -- token缓存2小时
        user = 3600,     -- 用户信息缓存1小时
        card = 1800      -- 卡牌信息缓存30分钟
    }
}

-- MySQL配置
M.mysql = {
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
}

-- 数据库常量
M.const = {
    -- 数据库相关
    DB = {
        RECONNECT_INTERVAL = 60,  -- 重连间隔（秒）
        MAX_RETRIES = 3,         -- 最大重试次数
        TIMEOUT = 1000,          -- 超时时间（毫秒）
        CHECK_INTERVAL = 60,     -- 检查间隔（秒）
        PING_INTERVAL = 30       -- 心跳间隔（秒）
    }
}

return M 