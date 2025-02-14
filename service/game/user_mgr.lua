local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local jwt = require "jwt"
local cache = require "game.cache"

local M = {}

-- 获取用户信息
function M.get_user(account)
    -- 获取用户信息
    local ok, response = pcall(cluster.call, "db_proxy", "@db_proxy", "get_user", account)
    if not ok then
        logger.error("Failed to get user info: %s", response)
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
            message = "Database error"
        }
    end
    
    if not response.success then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
            message = response.error
        }
    end
    
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        user = response.user
    }
end

-- 从缓存获取用户卡包
function M.get_user_cards_from_cache(user_id)
    if not user_id then
        return nil
    end
    
    local cards = cache.get_user_cards(user_id)
    if cards then
        logger.debug("Got cards from cache for user: %d", user_id)
    end
    return cards
end

-- 缓存用户卡包
function M.cache_user_cards(user_id, cards)
    if not user_id or not cards then
        return false
    end
    
    local ok = cache.set_user_cards(user_id, cards)
    if ok then
        logger.debug("Cached cards for user: %d", user_id)
    end
    return ok
end

-- 清除用户卡包缓存
function M.clear_user_cards_cache(user_id)
    if not user_id then
        return false
    end
    
    local ok = cache.remove_user_cards(user_id)
    if ok then
        logger.debug("Cleared cards cache for user: %d", user_id)
    end
    return ok
end

return M 