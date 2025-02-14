local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local jwt = require "jwt"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    -- 解码请求
    local base_request, request = message.decode_request(msg, "command.C2GHeartbeatRequest")
    if not base_request then
        return message.encode_response(message.create_error_response(nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO"),
            "Invalid proto"))
    end

    -- 打印调试信息
    logger.debug("Heartbeat request: %s", utils.table_to_string(request))

    -- 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Invalid token in heartbeat")
        return message.encode_response(message.create_error_response(base_request.session,
            token_result.code, token_result.message))
    end

    -- 更新用户最后心跳时间
    if not _G.client_heartbeats then
        _G.client_heartbeats = {}
    end
    _G.client_heartbeats[token_result.claims.account] = os.time()
    
    logger.debug("Updated heartbeat time for account %s: %d", 
        token_result.claims.account, _G.client_heartbeats[token_result.claims.account])

    -- 创建心跳响应
    local heartbeat_response = {
        timestamp = os.time(),
        code = 0
    }

    -- 创建基础响应
    local base_response = message.create_base_response(
        base_request.session,
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "Success",
        pb.encode("command.G2CHeartbeatResponse", heartbeat_response)
    )

    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_HEARTBEAT_RESPONSE")

    -- 编码并返回响应
    return message.encode_response(base_response)
end

return M 