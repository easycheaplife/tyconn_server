local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local map_service = require "services.map_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local utils = require "utils"
local error = require "error"   
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling map info request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GMapInfoRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CMapInfoResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_MAP_INFO_RESPONSE)
    end

    -- 获取用户地图信息
    local map_info = map_service.get_map_info(user.user_id)
    if not map_info then
        logger.error("Failed to get map info for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CMapInfoResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            "Failed to get map info", 
            message.MessageID.G2C_MAP_INFO_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        chapter_id = map_info.chapter_id,
        current_position = map_info.current_position,
        direction = map_info.direction
    }

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CMapInfoResponse",
        response_data,
        message.MessageID.G2C_MAP_INFO_RESPONSE)
end

return M 