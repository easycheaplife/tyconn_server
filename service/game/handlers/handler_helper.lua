local pb = require "pb"
local logger = require "logger"
local message = require "message"
local user = require "game.models.user"

local M = {}

-- 验证请求并获取用户信息
function M.verify_request_with_user(client_id, msg, proto_name)
    -- 1. 解码请求
    local base_request, request = message.decode_request(msg, proto_name)
    if not base_request then
        logger.error("Invalid proto for client: %d", client_id)
        return base_request, request, 
          tonumber(pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO")),
          "Invalid proto",
          nil,
          nil
    end

    -- 2. 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then  
        logger.error("Invalid token for client: %d, code: %d", client_id, token_result.code)
        return base_request, 
               request,
               tonumber(token_result.code),  -- 确保是数字类型
               "Invalid token",
               nil,
               nil
    end

    -- 3. 获取用户信息
    local user_info = user.get_user_from_cache(token_result.claims.account)
    if not user_info then
        -- 缓存中没有，从数据库获取
        local ok, err = user.get_user(token_result.claims.account)
        if not ok then
            logger.error("Failed to get user: %s", err)
            return base_request, request, 
              tonumber(pb.enum("common.ErrorCode", "ERROR_CODE_ACCOUNT_NOT_EXIST")),
              err,
              nil,
              nil
        end
        -- 将用户信息存入缓存
        user_info = err
        user.cache_user(user_info)
    end

    if not user_info then
        logger.error("User not found")
        return base_request, request, 
          tonumber(pb.enum("common.ErrorCode", "ERROR_CODE_ACCOUNT_NOT_EXIST")),
          "User not found",
          nil,
          nil
    end
    
    return base_request, request, 
      tonumber(pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS")),
      "Success", user_info, token_result.claims
end

-- 验证请求（不需要用户信息的接口使用）
function M.verify_request(client_id, msg, proto_name)
    -- 1. 解码请求
    local base_request, request = message.decode_request(msg, proto_name)
    if not base_request then
        logger.error("Invalid proto for client: %d", client_id)
        return base_request, request, 
          tonumber(pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO")),
          "Invalid proto",
          nil
    end

    -- 2. 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then  
        logger.error("Invalid token for client: %d, code: %d", client_id, token_result.code)
        return base_request, 
               request,
               tonumber(token_result.code),  -- 确保是数字类型
               "Invalid token",
               nil
    end
    return base_request, request, 
      tonumber(pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS")),
      "Success",
      token_result.claims
end

-- 创建成功响应
function M.create_success_response(base_request, proto_name, data, message_id)
    local base_response = message.create_base_response(
        base_request.session,
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "Success",
        pb.encode(proto_name, data))
    
    base_response.session.messageId = message_id
    return message.encode_response(base_response)
end

-- 创建错误响应
function M.create_error_response(base_request, error_code, proto_name, data, message_id)
    local response = {
        session = base_request.session,
        errorCode = error_code,
        errorMsg = "Error",
        payload = data and proto_name and pb.encode(proto_name, data) or nil
    }

    if message_id then
        response.session.messageId = message_id
    end

    return message.encode_response(response)
end

return M