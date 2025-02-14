local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local user_mgr = require "game.user_mgr"
local db_client = require "game.db_client"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling card bag info request from client %d", client_id)
    
    -- 解码请求
    local base_request, request = message.decode_request(msg, "command.C2GUserCardBagRequest")
    if not base_request then
        return message.encode_response(message.create_error_response(nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO"),
            "Invalid proto"))
    end

    -- 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Invalid token for client: %d", client_id)
        return message.encode_response(message.create_error_response(base_request.session,
            token_result.code, token_result.message))
    end

    -- 获取用户信息
    local result = user_mgr.get_user(token_result.claims.account)
    if result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        return message.encode_response(message.create_error_response(base_request.session,
            result.code, result.message))
    end

    -- 先从缓存获取用户卡包
    local cards = user_mgr.get_user_cards_from_cache(result.user.user_id)
    if not cards then
        -- 缓存中没有，从数据库获取
        cards = db_client.get_user_cards(result.user.user_id)
        if not cards then
            logger.error("Failed to get cards for user: %d", result.user.user_id)
            return message.encode_response(message.create_error_response(base_request.session,
                pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
                "Failed to get user cards"))
        end
        -- 将数据库中获取的卡包信息存入缓存
        user_mgr.cache_user_cards(result.user.user_id, cards)
    end

    -- 转换数据库字段到协议字段
    local protocol_cards = {}
    for _, card in ipairs(cards) do
        table.insert(protocol_cards, {
            card_id = card.card_id,
            card_type = card.card_type or 1, -- 默认类型
            level = card.level,
            exp = card.exp,
            quality = card.quality,
            star = card.star,
            create_time = card.create_time,
            power = card.power
        })
    end

    -- 创建响应
    local response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        cards = protocol_cards
    }

    -- 创建成功响应
    local base_response = message.create_base_response(
        base_request.session,
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "Success",
        pb.encode("command.G2CUserCardBagResponse", response)
    )

    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_USER_CARD_BAG_RESPONSE")

    -- 编码并返回响应
    return message.encode_response(base_response)
end

return M 