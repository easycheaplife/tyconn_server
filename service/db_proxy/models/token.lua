local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.user"
local db_util = require "db_proxy.utils.db_util"

local M = {}

-- 同步token
function M.sync_token(token_info)
    logger.debug("Saving token for user: %s", token_info.account)
    
    return db_util.transaction(function()
        -- 删除旧token
        local query = string.format(sql.DELETE_OLD_TOKENS, 
            db_util.escape(token_info.account))
        
        local ok, results = pcall(db_util.query, query)
        if not ok then
            logger.error("Failed to delete old tokens: %s", results)
            return false, "Database error"
        end
        
        -- 插入新token
        query = string.format(sql.SYNC_TOKEN,
            db_util.escape(token_info.account),
            db_util.escape(token_info.token),
            db_util.escape(token_info.device_id or ""),
            db_util.escape(token_info.platform or ""),
            token_info.expire_time,
            token_info.create_time
        )
        
        ok, results = pcall(db_util.query, query)
        if not ok then
            logger.error("Failed to insert token: %s", results)
            return false, "Database error"
        end
        
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