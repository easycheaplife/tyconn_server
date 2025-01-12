return {
    -- 数据库连接配置
    connection = {
        host = "127.0.0.1",
        port = 3306,
        user = "root",
        password = "F0BYKDqw7",
        charset = "utf8mb4",
        max_packet_size = 1024 * 1024
    },
    
    -- 数据库名称
    database = "tyconn",
    
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