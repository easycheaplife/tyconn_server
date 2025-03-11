local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local error = require "error"
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    -- 验证请求
    local base_request, request, error_code, error_message, claims = handler_helper.verify_request(
        client_id, msg, "command.C2GHeartbeatRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        return message_helper.create_error_response(
            base_request, 
            error_code, 
            "command.G2CHeartbeatResponse", 
            nil, 
            message.G2C_HEARTBEAT_RESPONSE)
    end

    -- 更新用户最后心跳时间
    if not _G.client_heartbeats then
        _G.client_heartbeats = {}
    end
    _G.client_heartbeats[claims.account] = os.time()
    
    logger.debug("Updated heartbeat time for account %s: %d", 
        claims.account, _G.client_heartbeats[claims.account])

    -- 创建响应
    local response = {
        code = 0,
        message = "success",
        timestamp = os.time()
    }

    return message_helper.create_success_response(
        base_request,
        "command.G2CHeartbeatResponse",
        response,
        message.G2C_HEARTBEAT_RESPONSE)
end

return M 