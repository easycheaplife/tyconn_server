local pb = require "pb"
local logger = require "logger"

local M = {}

-- 打印表内容的辅助函数
function M.table_to_string(t)
    if type(t) ~= "table" then
        return tostring(t)
    end
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            table.insert(result, k .. "=" .. M.table_to_string(v))
        else
            table.insert(result, k .. "=" .. tostring(v))
        end
    end
    return "{" .. table.concat(result, ", ") .. "}"
end

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
    return {
        session = session or M.create_session(),
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