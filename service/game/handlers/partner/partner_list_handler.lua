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
    logger.debug("Handling partner list request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GPartnerListRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerListResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_PARTNER_LIST_RESPONSE)
    end

    -- 获取用户伙伴列表
    local partners = partner_service.get_user_partners(user.user_id)
    if not partners then
        logger.error("Failed to get partners for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerListResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            nil, 
            message.MessageID.G2C_PARTNER_LIST_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        partners = partners
    }

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CPartnerListResponse",
        response_data,
        message.MessageID.G2C_PARTNER_LIST_RESPONSE)
end

return M 