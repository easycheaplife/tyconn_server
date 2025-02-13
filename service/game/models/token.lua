local skynet = require "skynet"
local logger = require "logger"
local jwt = require "jwt"
local cache = require "game.cache"
local db_client = require "game.db_client"

local M = {}

-- 获取token信息
function M.get_token(account)
    -- 1. 从缓存获取
    local token = cache.get_token(account)
    if token then
        logger.debug("Get token from cache: %s", account)
        return token
    end

    -- 2. 从数据库获取
    local db_token = db_client.get_token(account)
    if not db_token then
        logger.debug("Token not found for account: %s", account)
        return nil
    end

    -- 3. 写入缓存
    cache.set_token(account, db_token)
    logger.debug("Token cached for account: %s", account)

    return db_token
end

-- 验证token
function M.verify_token(token)
    -- 1. 验证JWT签名
    local ok, claims = pcall(jwt.decode, token, skynet.getenv("jwt_secret"))
    if not ok or not claims or not claims.account then
        logger.error("JWT验证失败: %s", token)
        return false, "Invalid token"
    end

    -- 2. 获取并验证token
    local db_token = M.get_token(claims.account)
    if not db_token then
        logger.error("Token not found: %s", claims.account)
        return false, "Token not found"
    end

    if db_token ~= token then
        logger.error("Token不匹配: %s != %s", token, db_token)
        return false, "Invalid token"
    end

    return true, claims.account
end

return M