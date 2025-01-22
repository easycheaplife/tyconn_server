local skynet = require "skynet"
local pb = require "pb"
local logger = require "logger"
local create_base_response = require "game.utils.response".create_base_response

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end

    -- 解码请求
    local ok, get_role_request = pcall(pb.decode, "command.C2GGetRoleRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode get role request: %s", get_role_request)
        return nil
    end

    -- 获取角色信息
    local response = skynet.call(skynet.self(), "lua", "get_role", get_role_request.token)
    
    -- 创建基础响应
    local base_response = create_base_response(base_request.session, 0, "success", 
        pb.encode("command.G2CGetRoleResponse", response))
    
    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_GET_ROLE_RESPONSE")
    
    -- 编码并返回响应
    return pb.encode("common.BaseResponse", base_response)
end

return M 