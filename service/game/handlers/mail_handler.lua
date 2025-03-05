local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local mail_service = require "services.mail_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"
local utils = require "utils"

local M = {}

-- 获取邮件列表
function M.handle_mail_list(client_id, msg)
    logger.debug("Handling mail list request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GMailListRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message.create_error_response(
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
        return message.create_error_response(
            base_request, 
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
            "command.G2CMailListResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_MAIL_LIST_RESPONSE"))
    end

    -- 构造响应数据
    local response_data = {
        mails = mails
    }
    
    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CMailListResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_MAIL_LIST_RESPONSE"))
end

-- 读取邮件
function M.handle_read_mail(client_id, msg)
    logger.debug("Handling read mail request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GReadMailRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
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
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
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

-- 领取邮件附件
function M.handle_claim_mail_items(client_id, msg)
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

-- 删除邮件
function M.handle_delete_mail(client_id, msg)
    logger.debug("Handling delete mail request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GDeleteMailRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d", client_id)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CDeleteMailResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_DELETE_MAIL_RESPONSE"))
    end

    -- 删除邮件
    local ok = mail_service.delete_mail(user.user_id, request.mail_id)
    if not ok then
        logger.error("Failed to delete mail: %s for user: %d", request.mail_id, user.user_id)
        return message.create_error_response(
            base_request, 
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
            "command.G2CDeleteMailResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_DELETE_MAIL_RESPONSE"))
    end

    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CDeleteMailResponse",
        { mail_id = request.mail_id },
        pb.enum("common.MessageID", "G2C_DELETE_MAIL_RESPONSE"))
end

return M 