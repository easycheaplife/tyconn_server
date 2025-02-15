local M = {}

-- Redis配置
M.redis = {
    -- 基础配置
    host = "127.0.0.1",
    port = 6379,
    db = 0,
    auth = nil,  -- 如果需要密码验证，在这里设置

    -- 缓存前缀
    prefix = {
        token = "token:",    -- token缓存前缀
        user = "user:",      -- 用户信息缓存前缀
        card = "card:",      -- 卡牌信息缓存前缀
        user_cards = "user_cards:",  -- 用户卡组缓存前缀
        user_items = "user_items:",  -- 用户物品缓存前缀
    },

    -- 缓存过期时间(秒)
    expire = {
        token = 7200,       -- token缓存2小时
        user = 3600,        -- 用户信息缓存1小时
        card = 1800,        -- 卡牌信息缓存30分钟
        user_cards = 3600,   -- 用户卡组缓存1小时
        user_items = 3600,   -- 用户物品缓存1小时
    }
}

-- MySQL配置
M.mysql = {
    -- 连接配置
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
    
    -- 连接池配置
    pool = {
        max_connections = 5,
        idle_timeout = 60,  -- 秒
        min_connections = 2,  -- 最小连接数
        reconnect_interval = 60,  -- 重连间隔（秒）
    },

    -- 查询配置
    query = {
        max_retries = 3,     -- 最大重试次数
        retry_delay = 1,     -- 重试延迟（秒）
        timeout = 1000,      -- 查询超时（毫秒）
    }
}

return M 