local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local mail_service = require "services.mail_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local error = require "error"   

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling mail list request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GMailListRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d", client_id)
        return message_helper.create_error_response(
            base_request, 
            error_code, 
            "command.G2CMailListResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_MAIL_LIST_RESPONSE"))
    end

    -- 获取用户邮件列表
    local mails = mail_service.get_user_mails(user.user_id)
    if not mails then
        logger.error("Failed to get mails for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_DB_ERROR, 
            "command.G2CMailListResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_MAIL_LIST_RESPONSE"))
    end

    -- 构造响应数据
    local response_data = {
        mails = mails
    }
    
    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CMailListResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_MAIL_LIST_RESPONSE"))
end

return M 