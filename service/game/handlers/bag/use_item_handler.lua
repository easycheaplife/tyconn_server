local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local item_service = require "services.item_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling use item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUseItemRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CUseItemResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
    end

    -- 参数验证
    if not request.item_id or request.item_id <= 0 then
        logger.error("Invalid item id: %s", tostring(request.item_id))
        return message.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM"),
            "command.G2CUseItemResponse",
            "Invalid item id",
            pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
    end

    if not request.count or request.count <= 0 then
        local error_code = pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM")
        logger.error("Invalid count: %s, error_code: %d", tostring(request.count), error_code)
        return message.create_error_response(
            base_request,
            error_code,
            "command.G2CUseItemResponse",
            "Invalid count",
            pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
    end

    -- 使用物品
    logger.info("Use item - user_id: %d, item_id: %d, count: %d", 
        user.user_id, request.item_id, request.count)
    local error_code, error_msg, result = item_service.use_item(user.user_id, request.item_id, request.count)
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        return message.create_error_response(
            base_request,
            error_code,
            "command.G2CUseItemResponse",
            error_msg,
            pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
    end

    -- 返回变化的物品列表
    local response_data = {
        items = result
    }

    return message.create_success_response(
        base_request,
        "command.G2CUseItemResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
end

return M 