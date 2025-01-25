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
    local user, err = verify_token_and_get_user(token)
    if not user then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = err
        }
    end
    
    -- 从数据库获取用户信息
    local ok, user_info = pcall(cluster.call, "db_proxy", "@db_proxy", "get_user", user.user_id)
    if not ok then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "获取用户信息失败"
        }
    end
    
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        has_user = user_info and user_info.name ~= "",
        user = user_info
    }
end

-- 创建用户
function M.create_user(token, name, gender, job)
    -- 验证token
    local user, err = verify_token_and_get_user(token)
    if not user then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = err
        }
    end
    
    -- 检查用户名是否已存在
    local ok, exists = pcall(cluster.call, "db_proxy", "@db_proxy", "check_name_exists", name)
    if not ok then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "系统错误"
        }
    end
    
    if exists then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_NAME_EXISTS"),
            message = "用户名已存在"
        }
    end
    
    -- 创建用户
    local ok, user_info = pcall(cluster.call, "db_proxy", "@db_proxy", "update_user", {
        user_id = user.user_id,
        name = name,
        gender = gender,
        job = job,
        level = 1,
        exp = 0,
        vip_level = 0,
        create_time = os.time(),
        login_time = os.time()
    })
    
    if not ok or not user_info then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "创建用户失败"
        }
    end
    
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        user = user_info
    }
end

return M 