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
        logger.debug("Decoded base request: %s", utils.table_to_string(base_request.session))
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
    logger.debug("Decoded request: %s", utils.table_to_string(request))
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

    local ok, claims = pcall(jwt.decode, token, skynet.getenv("jwt_secret"), true)
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

-- 编码基础响应
function M.encode_response(response)
    -- 确保错误码被正确编码
    local base_response = {
        session = response.session,
        errorCode = response.errorCode,  -- 修改这里，使用相同的字段名
        errorMsg = response.errorMsg,    -- 修改这里，使用相同的字段名
        payload = response.payload
    }
    
    return pb.encode("common.BaseResponse", base_response)
end

-- 创建成功响应
function M.create_success_response(base_request, proto_name, data, message_id)
    -- 加日志
    logger.debug("Creating success response with params:")
    logger.debug("- base_request: %s", utils.table_to_string(base_request))
    logger.debug("- proto_name: %s", proto_name)
    logger.debug("- data: %s", utils.table_to_string(data))
    logger.debug("- message_id: %d", message_id)

    local response = {
        session = {
            messageId = message_id,
            sequence = base_request.session.sequence,
            timestamp = base_request.session.timestamp,
            version = base_request.session.version
        },
        errorCode = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        errorMsg = "Success",
        payload = pb.encode(proto_name, data)
    }
    -- 打印完整响应
    logger.debug("Full success response: %s", utils.table_to_string(response))
    return M.encode_response(response)
end

-- 创建错误响应
function M.create_error_response(base_request, error_code, response_type, error_message, message_id)
    -- 确保错误码是数字
    if type(error_code) ~= "number" then
        logger.error("Invalid error code type: %s, value: %s", type(error_code), tostring(error_code))
        error_code = pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM")
    end

    -- 打印所有参数
    logger.debug("Creating error response with params:")
    logger.debug("- error_code: %d", error_code)
    logger.debug("- response_type: %s", response_type)
    logger.debug("- error_message: %s", error_message)
    logger.debug("- message_id: %d", message_id)

    local response = {
        session = {
            messageId = message_id,
            sequence = base_request.session.sequence,
            timestamp = base_request.session.timestamp,
            version = base_request.session.version
        },
        errorCode = error_code,
        errorMsg = error_message or "",
        payload = ""
    }

    -- 打印完整响应
    logger.debug("Full error response: %s", utils.table_to_string(response))

    return M.encode_response(response)
end

return M 