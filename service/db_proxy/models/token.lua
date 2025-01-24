local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.user"
local db_util = require "db_proxy.utils.db_util"

local M = {}

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
        -- 删除旧token
        local query = string.format(sql.DELETE_OLD_TOKENS, 
            db_util.escape(token_info.account))
        logger.debug("Deleting old tokens - SQL: %s", query)
        
        local ok, results = pcall(db_util.query, query)
        if not ok then
            logger.error("Failed to delete old tokens: %s, SQL: %s", results, query)
            return false, "Database error"
        end
        if not results then
            logger.error("Delete query returned nil")
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
        
        ok, results = pcall(db_util.query, query)
        if not ok then
            logger.error("Failed to insert token: %s, SQL: %s", results, query)
            return false, "Database error"
        end
        if not results then
            logger.error("Insert query returned nil")
            return false, "Database error"
        end
        logger.info("Successfully synced token for account: %s", token_info.account)
        
        return true
    end)
end

-- 验证token
function M.verify_token(account, token)
    local query = string.format(sql.GET_TOKEN,
        db_util.escape(account),
        db_util.escape(token)
    )
    
    local ok, results = pcall(db_util.query, query)
    if not ok then
        logger.error("Failed to verify token: %s", results)
        return false, "Database error"
    end
    
    if not results[1] then
        return false, "Token not found"
    end
    
    -- 检查token是否过期
    if results[1].expire_time < os.time() then
        return false, "Token expired"
    end
    
    return true
end

-- 清理过期token
function M.clean_expired_tokens()
    local query = string.format(sql.CLEAN_EXPIRED_TOKENS, os.time())
    
    local ok, results = pcall(db_util.query, query)
    if not ok then
        logger.error("Failed to clean expired tokens: %s", results)
        return false
    end
    
    if results.affected_rows > 0 then
        logger.info("Cleaned %d expired tokens", results.affected_rows)
    end
    
    return true
end

return M