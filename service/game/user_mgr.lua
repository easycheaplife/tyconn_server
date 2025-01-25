local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local jwt = require "jwt"

local M = {}

-- 验证token并获取用户信息
function M.verify_token_and_get_user(token)
    -- 验证token
    local ok, claims = pcall(jwt.decode, token, skynet.getenv("jwt_secret"))
    if not ok or not claims then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = "Invalid token"
        }
    end
    
    -- 获取用户信息
    local ok, response = pcall(cluster.call, "db_proxy", "@db_proxy", "get_user", claims.account)
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

-- 获取用户信息
function M.get_user(token)
    -- 验证token
    local result = M.verify_token_and_get_user(token)
    if result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        return result
    end
    
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        has_user = result.user ~= nil,
        user = result.user
    }
end

return M 