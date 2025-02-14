local pb = require "pb"
local logger = require "logger"
local utils = require "utils"
local jwt = require "jwt"
local skynet = require "skynet"

local M = {}

-- 解码基础请求和具体请求
function M.decode_request(msg, request_type)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end
    
    if base_request and base_request.session then
        logger.debug("Decoded base request: messageId=%d, sequence=%d", 
            base_request.session.messageId or 0,
            base_request.session.sequence or 0
        )
    end

    -- 如果没有指定具体请求类型，直接返回基础请求
    if not request_type then
        return base_request
    end

    -- 解码具体请求
    local ok, request = pcall(pb.decode, request_type, base_request.payload)
    if not ok then
        logger.error("Failed to decode request payload: %s", request)
        return nil
    end

    return base_request, request
end

-- 验证Token
function M.verify_token(token)
    if not token then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = "Missing token"
        }
    end

    local ok, claims = pcall(jwt.decode, token, skynet.getenv("jwt_secret"))
    if not ok or not claims then
        logger.error("Failed to decode token")
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = "Invalid token"
        }
    end

    if not claims.account then
        logger.error("Missing account in token claims")
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = "Invalid token format"
        }
    end

    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        claims = claims
    }
end

-- 创建会话信息
function M.create_session(messageId, sequence, version)
    return {
        messageId = messageId or 0,
        sequence = sequence or 0,
        timestamp = os.time(),
        version = version or "1.0.0"
    }
end

-- 创建基础响应
function M.create_base_response(session, errorCode, errorMsg, payload)
    -- 确保所有字段都有默认值
    local new_session = session or M.create_session()
    new_session.timestamp = os.time()  -- 更新时间戳
    
    return {
        session = new_session,
        errorCode = errorCode or 0,
        errorMsg = errorMsg or "",
        payload = payload or ""
    }
end

-- 创建错误响应
function M.create_error_response(session, errorCode, errorMsg)
    return M.create_base_response(session, errorCode, errorMsg)
end

-- 创建成功响应
function M.create_success_response(session, payload)
    return M.create_base_response(session, 0, "", payload)
end

-- 编码基础响应
function M.encode_response(base_response)
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", base_response)
    if not ok then
        logger.error("Failed to encode base response: %s", encoded)
        return nil
    end
    return encoded
end

return M 