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
    logger.debug("Handling cell event request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GHandleCellEventRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CHandleCellEventResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_HANDLE_CELL_EVENT_RESPONSE)
    end

    -- 验证请求参数
    if not request.event_id then
        logger.error("Missing event_id in request from client: %d", client_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CHandleCellEventResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAM, 
            "Missing event ID", 
            message.MessageID.G2C_HANDLE_CELL_EVENT_RESPONSE)
    end

    if not request.cell_id then
        logger.error("Missing cell_id in request from client: %d", client_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CHandleCellEventResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAM, 
            "Missing cell ID", 
            message.MessageID.G2C_HANDLE_CELL_EVENT_RESPONSE)
    end

    -- 处理格子事件
    local result = map_service.handle_cell_event(user.user_id, request.event_id, request.cell_id)
    if not result then
        logger.error("Failed to handle cell event for user: %d, event_id: %d, cell_id: %d", 
            user.user_id, request.event_id, request.cell_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CHandleCellEventResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            "Failed to handle cell event", 
            message.MessageID.G2C_HANDLE_CELL_EVENT_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        event_id = request.event_id,
        success = result.success,
        bags = result.bags or {},
        next_event_id = result.next_event_id or 0,
        remaining_events = result.remaining_events or {}
    }

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CHandleCellEventResponse",
        response_data,
        message.MessageID.G2C_HANDLE_CELL_EVENT_RESPONSE)
end

return M 