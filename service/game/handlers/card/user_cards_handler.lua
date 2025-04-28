local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message_helper = require "message_helper" 
local card_service = require "services.card_service"
local handler_helper = require "game.handlers.handler_helper"
local utils = require "utils"
local error = require "error"   
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling card bag request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUserCardsRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CUserCardsResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_USER_CARDS_RESPONSE)
    end

    -- 获取用户卡牌背包
    local cards = card_service.get_user_cards(user.user_id)
    if not cards then
        logger.error("Failed to get cards for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CUserCardsResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            nil, 
            message.MessageID.G2C_USER_CARDS_RESPONSE)
    end

    -- 打印调试信息
    logger.debug("User cards: %s", utils.table_to_string(cards))

    -- 构造响应数据
    local response_data = {
        cards = cards
    }

    logger.debug("Sending card bag response: %s", utils.table_to_string(response_data))

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CUserCardsResponse",
        response_data,
        message.MessageID.G2C_USER_CARDS_RESPONSE)
end

return M 