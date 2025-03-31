local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local map_service = require "services.map_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local utils = require "utils"
local error = require "error"   
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling claim reward request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GClaimRewardRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CClaimRewardResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_CLAIM_REWARD_RESPONSE)
    end

    -- 领取章节奖励
    local result = map_service.claim_chapter_reward(user.user_id)
    if not result then
        logger.error("Failed to claim chapter reward for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CClaimRewardResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            "Failed to claim reward", 
            message.MessageID.G2C_CLAIM_REWARD_RESPONSE)
    end

    -- 如果未成功领取（可能未满足条件）
    if not result.success then
        logger.warn("Cannot claim chapter reward for user: %d, conditions not met", user.user_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CClaimRewardResponse",
            error.ErrorCode.ERROR_CODE_INVALID_OPERATION, 
            "Cannot claim reward now", 
            message.MessageID.G2C_CLAIM_REWARD_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        success = result.success,
        bags = result.bags or {},
        next_chapter = result.next_chapter
    }

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CClaimRewardResponse",
        response_data,
        message.MessageID.G2C_CLAIM_REWARD_RESPONSE)
end

return M 