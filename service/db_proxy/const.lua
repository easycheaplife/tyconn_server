local M = {}

-- 数据库相关常量
M.DB = {
    -- 清理过期token的间隔时间(秒)
    CLEAN_TOKEN_INTERVAL = 3600,
    
    -- 数据库重连最大尝试次数
    MAX_RECONNECT_ATTEMPTS = 3,
    
    -- 数据库重连间隔(毫秒)
    RECONNECT_INTERVAL = 1000,
    
    -- 事务超时时间(秒)
    TRANSACTION_TIMEOUT = 10,
    
    -- 批量操作的大小限制
    BATCH_SIZE = 1000
}

-- 缓存相关常量
M.CACHE = {
    -- 用户信息缓存过期时间(秒)
    USER_EXPIRE = 300,
    
    -- token缓存过期时间(秒)
    TOKEN_EXPIRE = 300,
    
    -- 缓存大小限制
    MAX_CACHE_SIZE = 10000
}

return M 