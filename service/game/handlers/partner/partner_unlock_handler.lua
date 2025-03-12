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
    logger.debug("Handling partner unlock request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GPartnerUnlockRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerUnlockResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_PARTNER_UNLOCK_RESPONSE)
    end

    -- 检查参数
    if not request.unit_id then
        logger.error("Missing unit_id in request")
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerUnlockResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAMETER, 
            "Missing unit_id", 
            message.MessageID.G2C_PARTNER_UNLOCK_RESPONSE)
    end

    -- 解锁伙伴
    local result, unlocked_partner, consumed_fragments = partner_service.unlock_partner(user.user_id, request.unit_id)
    if not result then
        logger.error("Failed to unlock partner for user: %d, unit_id: %d", user.user_id, request.unit_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerUnlockResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            nil, 
            message.MessageID.G2C_PARTNER_UNLOCK_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        partner = unlocked_partner,
        consumed_fragments = consumed_fragments
    }

    logger.debug("Sending partner unlock response: %s", utils.table_to_string(response_data))

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CPartnerUnlockResponse",
        response_data,
        message.MessageID.G2C_PARTNER_UNLOCK_RESPONSE)
end

return M 