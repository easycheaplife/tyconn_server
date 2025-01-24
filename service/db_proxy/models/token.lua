local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.user"
local db_util = require "db_proxy.utils.db_util"
local cache = require "db_proxy.cache.cache"
local const = require "db_proxy.const"

-- 续费配置
local RENEW_CONFIG = {
    threshold = 3600,  -- 剩余1小时时自动续费
    duration = 86400,  -- 续费24小时
    max_idle_time = 604800,  -- 最大空闲时间(7天)
    check_interval = 3600    -- 续费检查间隔(1小时)
}

-- 记录最后检查时间
local last_check_time = {}

-- token缓存配置
local CACHE_CONFIG = {
    negative_ttl = 60,  -- 负缓存时间(秒)
}

-- 负缓存记录
local negative_cache = {}

local M = {}

-- 检查并触发续费
local function check_and_renew(account, token_info)
    -- 检查最后活跃时间
    local last_active = last_check_time[account] or token_info.create_time
    local idle_time = os.time() - last_active
    
    if idle_time > RENEW_CONFIG.max_idle_time then
        logger.info("Token idle too long, skip renew - Account: %s, Idle: %d", 
            account, idle_time)
        return false
    end
    
    -- 检查是否需要续费
    local remaining = token_info.expire_time - os.time()
    if remaining <= RENEW_CONFIG.threshold then
        local new_expire = os.time() + RENEW_CONFIG.duration
        skynet.fork(function()
            M.renew_token(account, token_info.token, new_expire)
        end)
        return true
    end
    
    return false
end

-- 同步token
function M.sync_token(token_info)
    -- 验证参数
    if not token_info then
        logger.error("token_info is nil")
        return false, "Invalid token info"
    end
    
    if not token_info.account or token_info.account == "" then
        logger.error("account is missing")
        return false, "Invalid account"
    end
    
    if not token_info.token or token_info.token == "" then
        logger.error("token is missing")
        return false, "Invalid token"
    end
    
    if not token_info.expire_time or token_info.expire_time <= 0 then
        logger.error("invalid expire_time: %s", tostring(token_info.expire_time))
        return false, "Invalid expire time"
    end

    logger.info("Syncing token - Account: %s, Device: %s, Platform: %s", 
        token_info.account,
        token_info.device_id or "none",
        token_info.platform or "none"
    )
    
    return db_util.transaction(function()
        -- 获取旧token信息用于判断是否需要保持续费
        local old_token = cache.get_token(token_info.account)
        
        -- 删除旧token
        local query = string.format(sql.DELETE_OLD_TOKENS, 
            db_util.escape(token_info.account))
        logger.debug("Deleting old tokens - SQL: %s", query)
        
        local results, err = db_util.query(query)
        if not results then
            logger.error("Failed to delete old tokens: %s, SQL: %s", err, query)
            return false, "Database error"
        end
        logger.debug("Deleted %d old tokens", results.affected_rows or 0)
        
        -- 插入新token
        query = string.format(sql.SYNC_TOKEN,
            db_util.escape(token_info.account),
            db_util.escape(token_info.token),
            db_util.escape(token_info.device_id or ""),
            db_util.escape(token_info.platform or ""),
            token_info.expire_time,
            token_info.create_time or os.time()
        )
        logger.debug("Inserting new token - Account: %s, SQL: %s", token_info.account, query)
        
        results, err = db_util.query(query)
        if not results then
            logger.error("Failed to insert token: %s, SQL: %s", err, query)
            return false, "Database error"
        end
        logger.info("Successfully synced token for account: %s", token_info.account)
        
        -- 如果是同一设备重新登录，继承上次的活跃时间
        if old_token and old_token.device_id == token_info.device_id then
            last_check_time[token_info.account] = last_check_time[token_info.account]
        else
            last_check_time[token_info.account] = os.time()
        end
        
        -- 更新缓存
        cache.set_token(token_info.account, token_info)
        
        return true
    end)
end

-- 验证token
function M.verify_token(account, token)
    -- 更新最后检查时间
    last_check_time[account] = os.time()
    
    -- 检查负缓存
    local neg_cache = negative_cache[account]
    if neg_cache then
        if os.time() - neg_cache.time < CACHE_CONFIG.negative_ttl then
            return false, neg_cache.reason
        else
            negative_cache[account] = nil
        end
    end
    
    -- 先查缓存
    local cached_token = cache.get_token(account)
    if cached_token then
        -- token不匹配，加入负缓存
        if cached_token.token ~= token then
            negative_cache[account] = {
                time = os.time(),
                reason = "Invalid token"
            }
            return false, "Invalid token"
        end

        if cached_token.expire_time > os.time() then
            check_and_renew(account, cached_token)
            return true
        else
            cache.remove_token(account)
            last_check_time[account] = nil
            -- 过期token加入负缓存
            negative_cache[account] = {
                time = os.time(),
                reason = "Token expired"
            }
            return false, "Token expired"
        end
    end
    
    local query = string.format(sql.GET_TOKEN,
        db_util.escape(account),
        db_util.escape(token)
    )
    
    local results, err = db_util.query(query)
    if not results then
        logger.error("Failed to verify token: %s", err)
        -- 数据库错误不加入负缓存
        return false, "Database error"
    end
    
    if not results[1] then
        -- token不存在加入负缓存
        negative_cache[account] = {
            time = os.time(),
            reason = "Token not found"
        }
        return false, "Token not found"
    end
    
    -- 检查token是否过期
    if results[1].expire_time < os.time() then
        last_check_time[account] = nil
        -- 过期token加入负缓存
        negative_cache[account] = {
            time = os.time(),
            reason = "Token expired"
        }
        return false, "Token expired"
    end
    
    check_and_renew(account, results[1])
    
    -- 更新缓存
    cache.set_token(account, results[1])
    
    return true
end

-- 清理过期token
function M.clean_expired_tokens()
    local current_time = os.time()
    logger.debug("Cleaning expired tokens before %d", current_time)
    
    local query = string.format(sql.CLEAN_EXPIRED_TOKENS, current_time)
    local results, err = db_util.query(query)
    if not results then
        logger.error("Failed to clean expired tokens: %s", err)
        return false
    end
    
    local affected = results.affected_rows or 0
    if affected > 0 then
        logger.info("Cleaned %d expired tokens", affected)
    end
    
    return true
end

-- 续费token
function M.renew_token(account, token, new_expire_time)
    logger.info("Renewing token - Account: %s", account)
    
    return db_util.transaction(function()
        -- 先验证token是否存在且有效
        local sql = string.format([[
            SELECT * FROM user_tokens 
            WHERE account = %s AND token = %s
            AND expire_time > %d
            LIMIT 1
        ]], 
        db_util.escape(account),
        db_util.escape(token),
        os.time())
        
        local results = db_util.query(sql)
        if not results or #results == 0 then
            logger.error("Token not found or expired - Account: %s", account)
            return false, "Invalid token"
        end
        
        -- 更新token过期时间
        sql = string.format([[
            UPDATE user_tokens SET expire_time = %d
            WHERE account = %s AND token = %s
        ]],
        new_expire_time,
        db_util.escape(account),
        db_util.escape(token))
        
        local ok = db_util.query(sql)
        if not ok then
            logger.error("Failed to renew token - Account: %s", account)
            return false, "Failed to renew token"
        end
        
        -- 更新缓存
        local token_info = results[1]
        token_info.expire_time = new_expire_time
        cache.set_token(account, token_info)
        
        logger.info("Successfully renewed token for account: %s", account)
        return true
    end)
end

return M