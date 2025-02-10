local pb = require "pb"
local logger = require "logger"
local utils = require "utils"

local M = {}

-- 解码基础请求
function M.decode_request(msg)

    local ok, request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", request)
        return nil
    end
    
    if request and request.session then
        logger.debug("Decoded base request: messageId=%d, sequence=%d", 
            request.session.messageId or 0,
            request.session.sequence or 0
        )
    end
    
    return request
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