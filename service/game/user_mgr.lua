local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local jwt = require "jwt"

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

return M 