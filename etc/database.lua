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
        user_info = "user_info:",  -- 用户信息缓存前缀(通过user_id)
        user_account = "user_account:",  -- 账号到用户ID的映射
        user_mails = "user_mails:",  -- 用户邮件列表缓存前缀
        mail_template = "mail_template:",  -- 邮件模板缓存前缀
        card = "card:",      -- 卡牌信息缓存前缀
        user_cards = "user_cards:",  -- 用户卡组缓存前缀
        user_items = "user_items:",  -- 用户物品缓存前缀
        user_bag = "bag:",
        user_bags = "bags:",
        bag_slots = "slots:",
        equip_slots = "equip:slots:",
        equip_level = "equip:level:",
        user_partners = "user_partners:",  -- 用户伙伴列表缓存前缀
        partner = "partner:",  -- 伙伴信息缓存前缀
        map_info = "map:user:",
        map_chapter = "map:chapter:",
        map_events = "map:events:"
    },

    -- 缓存过期时间(秒)
    expire = {
        token = 3600 * 24,     -- token 24小时
        user = 3600 * 24,      -- 用户信息 24小时
        user_mails = 3600,     -- 用户邮件列表 1小时
        mail_template = 3600,   -- 邮件模板 1小时
        card = 1800,        -- 卡牌信息缓存30分钟
        user_cards = 3600 * 24, -- 用户卡牌 24小时
        user_items = 3600 * 24,  -- 用户物品 24小时
        user_bag = 7200,    -- 2小时
        user_bags = 7200,   -- 2小时
        bag_slots = 7200,   -- 2小时
        equip_slots = 3600,  -- 1小时
        equip_level = 3600,  -- 1小时
        user_partners = 3600 * 12,  -- 用户伙伴列表 12小时
        partner = 3600 * 6,  -- 伙伴信息 6小时
        map_info = 3600,       -- 地图信息 1小时
        map_chapter = 3600,    -- 章节进度 1小时
        map_events = 3600      -- 格子事件 1小时
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
        max_retries = 1,     -- 最大重试次数
        retry_delay = 1,     -- 重试延迟（秒）
        timeout = 1000,      -- 查询超时（毫秒）
    }
}

return M 