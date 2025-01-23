local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message_util = require "game.utils.message"

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end

    -- 更新客户端最后心跳时间
    if not _G.client_heartbeats then
        _G.client_heartbeats = {}
    end
    _G.client_heartbeats[client_id] = os.time()
    logger.debug("Updated heartbeat time for client %d: %d", client_id, _G.client_heartbeats[client_id])
    
    -- 创建心跳响应
    local heartbeat_response = {
        timestamp = os.time(),
        code = 0
    }
    
    -- 创建基础响应
    local base_response = message_util.create_base_response(base_request.session, 0, "success",
        pb.encode("command.G2CHeartbeat", heartbeat_response))
    
    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_HEARTBEAT")
    
    -- 编码并返回响应
    return pb.encode("common.BaseResponse", base_response)
end

return M 