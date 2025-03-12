local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message_helper = require "message_helper" 
local partner_service = require "services.partner_service"
local handler_helper = require "game.handlers.handler_helper"
local utils = require "utils"
local error = require "error"   
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling partner star up request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GPartnerStarUpRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerStarUpResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_PARTNER_STAR_UP_RESPONSE)
    end

    -- 检查参数
    if not request.partner_id then
        logger.error("Missing partner_id in request")
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerStarUpResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAMETER, 
            "Missing partner_id", 
            message.MessageID.G2C_PARTNER_STAR_UP_RESPONSE)
    end

    -- 升星伙伴
    local result, updated_partner, property_changes, consumed_items = partner_service.star_up_partner(user.user_id, request.partner_id)
    if not result then
        logger.error("Failed to star up partner for user: %d, partner_id: %d", user.user_id, request.partner_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerStarUpResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            nil, 
            message.MessageID.G2C_PARTNER_STAR_UP_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        partner = updated_partner,
        property_changes = property_changes,
        consumed_items = consumed_items
    }

    logger.debug("Sending partner star up response: %s", utils.table_to_string(response_data))

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CPartnerStarUpResponse",
        response_data,
        message.MessageID.G2C_PARTNER_STAR_UP_RESPONSE)
end

return M 