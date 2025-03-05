local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local mail_service = require "services.mail_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling claim mail items request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GClaimMailItemsRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d", client_id)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CClaimMailItemsResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_CLAIM_MAIL_ITEMS_RESPONSE"))
    end

    -- 领取邮件附件
    local ok, items = mail_service.claim_mail_items(user.user_id, request.mail_id)
    if not ok then
        logger.error("Failed to claim mail items: %s for user: %d", request.mail_id, user.user_id)
        return message.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
            "command.G2CClaimMailItemsResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_CLAIM_MAIL_ITEMS_RESPONSE"))
    end

    -- 构造响应数据
    local response_data = {
        mail_id = request.mail_id,
        items = items
    }
    
    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CClaimMailItemsResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_CLAIM_MAIL_ITEMS_RESPONSE"))
end

return M 