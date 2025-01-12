-- 从环境变量读取数据库密码
local password = os.getenv("MYSQL_PASSWORD") or "123456"

return {
    -- 数据库连接配置
    connection = {
        host = "127.0.0.1",
        port = 3306,
        user = "root",
        password = password,
        charset = "utf8mb4",
        max_packet_size = 1024 * 1024,
		auth = "mysql_native_password"  -- 使用旧的认证方式
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
