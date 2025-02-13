local M = {}

-- 数据库相关常量
M.DB = {
    RECONNECT_INTERVAL = 60,  -- 重连间隔（秒）
    MAX_RETRIES = 3,         -- 最大重试次数
    TIMEOUT = 1000,          -- 超时时间（毫秒）
}

return M 