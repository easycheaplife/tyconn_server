local M = {}

-- 创建基础响应
function M.create_base_response(session, error_code, error_msg, payload)
    return {
        session = {
            messageId = session.messageId,  -- 由具体的处理器设置正确的响应消息ID
            sequence = session.sequence,
            timestamp = os.time(),
            version = session.version
        },
        errorCode = error_code or 0,
        errorMsg = error_msg or "success",
        payload = payload
    }
end

return M 