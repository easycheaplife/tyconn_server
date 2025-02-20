local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local item_service = require "services.item_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling bag info request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GBagInfoRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CBagInfoResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_BAG_INFO_RESPONSE"))
    end

    -- 获取用户物品列表
    local items = item_service.get_user_items(user.user_id)
    if not items then
        logger.error("Failed to get items for user: %d", user.user_id)
        return message.create_error_response(
            base_request, 
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
            "command.G2CBagInfoResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_BAG_INFO_RESPONSE"))
    end

    -- 构造响应数据
    local response_data = {
        items = items
    }

    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CBagInfoResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_BAG_INFO_RESPONSE"))
end

return M 