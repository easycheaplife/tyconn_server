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
    logger.debug("Handling equip level upgrade request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GEquipLevelUpgradeRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CEquipLevelUpgradeResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_EQUIP_LEVEL_UPGRADE_RESPONSE)
    end
    
    -- 解析请求参数
    local use_ad = request.use_ad
    local use_item = request.use_item
    local speedup_item_id = request.speedup_item_id
    
    local result, error_msg, upgrade_info
    
    -- 检查是否是升级中的加速请求
    local level_info = equip_service.get_equip_odds_level_info(user.user_id)
    if level_info.is_upgrading then
        -- 加速升级
        result, error_msg, upgrade_info = equip_service.speedup_equip_odds_level_upgrade(
            user.user_id, use_ad, use_item, speedup_item_id)
    else
        -- 开始新的升级
        result, error_msg, upgrade_info = equip_service.start_upgrade_equip_odds_level(user.user_id)
    end
    
    if not result then
        logger.error("Failed to upgrade equip level for user: %d, error: %s", 
            user.user_id, error_msg)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CEquipLevelUpgradeResponse",
            error.ErrorCode.ERROR_CODE_INVALID_OPERATION, 
            error_msg, 
            message.MessageID.G2C_EQUIP_LEVEL_UPGRADE_RESPONSE)
    end
    
    -- 获取当前概率等级信息
    local info = equip_service.get_equip_odds_level_info(user.user_id)
    
    -- 获取当前等级的品质概率
    local current_odds = {}
    if info.current_config then
        for i = 1, 9 do
            local key = "qua_" .. i
            current_odds[i] = info.current_config[key] or 0
        end
    end
    
    -- 构造响应数据
    local response_data = {
        current_level = info.current_level,
        remaining_time = info.remaining_time,
        is_upgrading = info.is_upgrading,
        current_odds = current_odds
    }
    
    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CEquipLevelUpgradeResponse",
        response_data,
        message.MessageID.G2C_EQUIP_LEVEL_UPGRADE_RESPONSE)
end

return M