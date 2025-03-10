local pb = require "pb"
local logger = require "logger"
local message = require "message"
local user_service = require "services.user_service"
local error = require "error"  -- 从lualib根目录加载错误码模块

local M = {}

-- 验证请求并获取用户信息
function M.verify_request_with_user(client_id, msg, proto_name)
    -- 1. 解码请求
    local base_request, request = message.decode_request(msg, proto_name)
    if not base_request then
        logger.error("Invalid proto for client: %d", client_id)
        return base_request, request, 
          error.ErrorCode.ERROR_CODE_INVALID_PROTO,
          "Invalid proto",
          nil,
          nil
    end

    -- 2. 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= error.ErrorCode.ERROR_CODE_SUCCESS then  
        logger.error("Invalid token for client: %d, code: %d", client_id, token_result.code)
        return base_request, 
               request,
               tonumber(token_result.code),  -- 确保是数字类型
               "Invalid token",
               nil,
               nil
    end

    -- 3. 获取用户信息
        -- 缓存中没有，从数据库获取
        local user_info = user_service.get_user(token_result.claims.account)
        if not user_info then
            logger.error("Failed to get user: %s", token_result.claims.account)
            return base_request, request, 
              error.ErrorCode.ERROR_CODE_ACCOUNT_NOT_EXIST,
              err,
              nil,
              nil
        end

    if not user_info then
        logger.error("User not found")
        return base_request, request, 
          error.ErrorCode.ERROR_CODE_ACCOUNT_NOT_EXIST,
          "User not found",
          nil,
          nil
    end
    
    return base_request, request, 
      error.ErrorCode.ERROR_CODE_SUCCESS,
      "Success", user_info, token_result.claims
end

-- 验证请求（不需要用户信息的接口使用）
function M.verify_request(client_id, msg, proto_name)
    -- 1. 解码请求
    local base_request, request = message.decode_request(msg, proto_name)
    if not base_request then
        logger.error("Invalid proto for client: %d", client_id)
        return base_request, request, 
          error.ErrorCode.ERROR_CODE_INVALID_PROTO,
          "Invalid proto",
          nil
    end

    -- 2. 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= error.ErrorCode.ERROR_CODE_SUCCESS then  
        logger.error("Invalid token for client: %d, code: %d", client_id, token_result.code)
        return base_request, 
               request,
               tonumber(token_result.code),  -- 确保是数字类型
               "Invalid token",
               nil
    end
    return base_request, request, 
      error.ErrorCode.ERROR_CODE_SUCCESS,
      "Success",
      token_result.claims
end

return M