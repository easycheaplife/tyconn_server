local pb = require "pb"
local logger = require "logger"
local message = require "message"
local user_mgr = require "game.user_mgr"

local M = {}

-- 验证请求并获取用户信息
function M.verify_request_with_user(client_id, msg, proto_name)
    -- 1. 解码请求
    local base_request, request = message.decode_request(msg, proto_name)
    if not base_request then
        return nil, nil, nil, message.encode_response(message.create_error_response(nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO"),
            "Invalid proto"))
    end

    -- 2. 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Invalid token for client: %d", client_id)
        return nil, nil, nil, message.encode_response(message.create_error_response(base_request.session,
            token_result.code, token_result.message))
    end

    -- 3. 获取用户信息
    local result = user_mgr.get_user_from_cache(token_result.claims.account)
    if not result then
        -- 缓存中没有，从数据库获取
        result = user_mgr.get_user(token_result.claims.account)
        if result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
            return nil, nil, nil, message.encode_response(message.create_error_response(base_request.session,
                result.code, result.message))
        end
        -- 将用户信息存入缓存
        user_mgr.cache_user(result.user)
    end

    if not result.user then
        return nil, nil, nil, message.encode_response(message.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_USER_NOT_FOUND"),
            "User not found"))
    end

    return base_request, request, result.user, token_result.claims
end

-- 验证请求（不需要用户信息的接口使用）
function M.verify_request(client_id, msg, proto_name)
    -- 1. 解码请求
    local base_request, request = message.decode_request(msg, proto_name)
    if not base_request then
        return nil, nil, nil, message.encode_response(message.create_error_response(nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO"),
            "Invalid proto"))
    end

    -- 2. 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Invalid token for client: %d", client_id)
        return nil, nil, nil, message.encode_response(message.create_error_response(base_request.session,
            token_result.code, token_result.message))
    end

    return base_request, request, token_result.claims
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

return M