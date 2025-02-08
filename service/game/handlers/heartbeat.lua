local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message_util = require "game.utils.message"
local jwt = require "jwt"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end

    -- 解码心跳请求
    local ok, heartbeat = pcall(pb.decode, "command.C2GHeartbeat", base_request.payload)
    if not ok then
        logger.error("Failed to decode heartbeat: %s", heartbeat)
        return nil
    end

    -- 打印调试信息
    logger.debug("Heartbeat request: %s", utils.table_to_string(heartbeat))

    -- 验证token
    if not heartbeat.token then
        logger.error("Missing token in heartbeat request")
        return message_util.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            "Missing token")
    end

    local ok, claims = pcall(jwt.decode, heartbeat.token, skynet.getenv("jwt_secret"))
    if not ok or not claims then
        logger.error("Invalid token in heartbeat")
        return message_util.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            "Invalid token")
    end

    -- 检查user_id
    if not claims.user_id then
        logger.error("Missing user_id in token claims: %s", utils.table_to_string(claims))
        return message_util.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            "Invalid token format: missing user_id")
    end

    -- 更新用户最后心跳时间
    if not _G.client_heartbeats then
        _G.client_heartbeats = {}
    end
    _G.client_heartbeats[claims.user_id] = os.time()
    
    logger.debug("Updated heartbeat time for user %d: %d", 
        claims.user_id, _G.client_heartbeats[claims.user_id])

    -- 创建心跳响应
    local heartbeat_response = {
        timestamp = os.time(),
        code = 0
    }

    -- 创建基础响应
    local base_response = message_util.create_base_response(
        base_request.session,
        0,
        "success",
        pb.encode("command.G2CHeartbeat", heartbeat_response)
    )

    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_HEARTBEAT")

    return pb.encode("common.BaseResponse", base_response)
end

return M 