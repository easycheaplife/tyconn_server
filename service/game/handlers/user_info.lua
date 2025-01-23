local skynet = require "skynet"
local pb = require "pb"
local logger = require "logger"
local create_base_response = require "game.utils.response".create_base_response

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling user info request from client %d", client_id)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end

    -- 解码请求
    local ok, request = pcall(pb.decode, "command.C2GUserInfoRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode user info request: %s", request)
        return nil
    end

    logger.debug("Processing user info request with token: %s", request.token)
    -- 先尝试获取用户信息
    local response = skynet.call(skynet.self(), "lua", "get_user", request.token)
    
    -- 如果用户不存在且提供了创建信息，则创建用户
    if not response.user and request.name and request.gender and request.job then
        logger.debug("Creating new user with name: %s", request.name)
        response = skynet.call(skynet.self(), "lua", "create_user", 
            request.token, request.name, request.gender, request.job)
        if response.code == pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
            response.is_new = true
        end
    end
    
    logger.debug("User info response: %s", response.message)
    -- 创建基础响应
    local base_response = create_base_response(base_request.session, response.code, response.message,
        pb.encode("command.G2CUserInfoResponse", response))
    
    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE")
    
    -- 编码并返回响应
    return pb.encode("common.BaseResponse", base_response)
end

return M 