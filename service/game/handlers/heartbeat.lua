local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message_util = require "game.utils.message"

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local base_request = message_util.decode_request(msg)
    if not base_request then
        logger.error("Failed to decode base request")
        return message_util.encode_response(message_util.create_error_response(
            nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end
    
    -- 解码心跳请求
    local ok, request = pcall(pb.decode, "command.C2SHeartbeat", base_request.payload)
    if not ok then
        logger.error("Failed to decode heartbeat request: %s", request)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end
    
    -- 构造心跳响应
    local response = {
        timestamp = os.time(),
        code = 0
    }
    
    -- 编码并返回响应
    local ok, payload = pcall(pb.encode, "command.S2CHeartbeat", response)
    if not ok then
        logger.error("Failed to encode heartbeat response: %s", payload)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "系统错误"
        ))
    end
    
    return message_util.encode_response(message_util.create_success_response(
        base_request.session,
        payload
    ))
end

return M 