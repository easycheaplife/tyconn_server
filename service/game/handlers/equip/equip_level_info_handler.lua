local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local equip_service = require "services.equip_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local error = require "error"  
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling equip level info request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GEquipLevelInfoRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            error_code, 
            "command.G2CEquipLevelInfoResponse", 
            nil, 
            message.MessageID.G2C_EQUIP_LEVEL_INFO_RESPONSE)
    end

    -- 获取装备概率等级信息
    local level_info = equip_service.get_equip_odds_level_info(user.user_id)
    if not level_info then
        logger.error("Failed to get equipment level info for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR,
            "command.G2CEquipLevelInfoResponse",
            nil,
            message.MessageID.G2C_EQUIP_LEVEL_INFO_RESPONSE
        )
    end
    
    -- 构造响应数据
    local response_data = level_info
    
    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CEquipLevelInfoResponse",
        response_data,
        message.MessageID.G2C_EQUIP_LEVEL_INFO_RESPONSE
    )
end

return M