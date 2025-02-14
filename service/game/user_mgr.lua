local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local jwt = require "jwt"
local cache = require "game.cache"

local M = {}

-- 从缓存获取用户信息
function M.get_user_from_cache(account)
    if not account then
        return nil
    end
    
    local user = cache.get_user_info(account)
    if user then
        logger.debug("Got user from cache: %s", account)
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
            message = "success",
            user = user
        }
    end
    return nil
end

-- 缓存用户信息
function M.cache_user(user)
    if not user or not user.account then
        logger.error("Failed to cache user: invalid user data")
        return false
    end
    
    logger.debug("Caching user info: %s", table.concat({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }, ", "))
    
    local ok = cache.set_user_info(user.account, user)
    if ok then
        logger.debug("Successfully cached user info for: %s", user.account)
    else
        logger.error("Failed to cache user info for: %s", user.account)
    end
    return ok
end

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

    -- 如果成功获取到用户数据，立即缓存
    if response.user then
        logger.debug("Got user from db: %s", table.concat({
            account = response.user.account,
            user_id = response.user.user_id,
            username = response.user.username
        }, ", "))
        
        local cache_ok = M.cache_user(response.user)
        if cache_ok then
            logger.debug("Successfully cached user info after db query: %s", account)
        else
            logger.error("Failed to cache user info after db query: %s", account)
        end
    else
        logger.debug("No user data in response for account: %s", account)
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

-- 清除用户缓存
function M.clear_user_cache(account)
    if not account then
        return false
    end
    
    local ok = cache.remove_user_info(account)
    if ok then
        logger.debug("Cleared user cache for: %s", account)
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