-- 从环境变量读取数据库密码
local host = os.getenv("MYSQL_HOST") or "127.0.0.1"
local user = os.getenv("MYSQL_USER") or "root"
local password = os.getenv("MYSQL_PASSWORD") or "123456"
local database = os.getenv("MYSQL_DATABASE") or "tyconn"

return {
    -- 数据库连接配置
    connection = {
        host = host,
        port = 3306,
        user = user,
        password = password,
        charset = "utf8mb4",
        max_packet_size = 1024 * 1024,
        auth = "mysql_native_password"  -- 使用旧的认证方式
    },
    
    -- 数据库名称
    database = database,
    
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
