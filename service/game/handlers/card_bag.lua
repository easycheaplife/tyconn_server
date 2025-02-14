local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local card = require "game.models.card"
local handler_helper = require "game.handlers.handler_helper"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling card bag info request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUserCardBagRequest")
    if not base_request then
        return request  -- 错误响应
    end

    -- 获取用户卡包
    local cards = card.get_user_cards(user.user_id)
    if not cards then
        logger.error("Failed to get cards for user: %d", user.user_id)
        return message.encode_response(message.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "Failed to get user cards"))
    end

    -- 创建响应
    local response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        cards = cards
    }

    return handler_helper.create_success_response(
        base_request,
        "command.G2CUserCardBagResponse",
        response,
        pb.enum("common.MessageID", "G2C_USER_CARD_BAG_RESPONSE"))
end

return M 