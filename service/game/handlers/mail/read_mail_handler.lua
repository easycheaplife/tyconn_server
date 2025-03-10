local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local mail_service = require "services.mail_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"
local error = require "game.define.error"  

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling read mail request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GReadMailRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d", client_id)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CReadMailResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_READ_MAIL_RESPONSE"))
    end

    -- 更新邮件状态为已读
    local ok = mail_service.read_mail(user.user_id, request.mail_id)
    if not ok then
        logger.error("Failed to read mail: %s for user: %d", request.mail_id, user.user_id)
        return message.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_DB_ERROR, 
            "command.G2CReadMailResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_READ_MAIL_RESPONSE"))
    end

    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CReadMailResponse",
        { mail_id = request.mail_id },
        pb.enum("common.MessageID", "G2C_READ_MAIL_RESPONSE"))
end

return M 