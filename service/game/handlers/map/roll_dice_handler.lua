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
    logger.debug("Handling roll dice request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GRollDiceRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CRollDiceResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_ROLL_DICE_RESPONSE)
    end

    -- 掷骰子
    local roll_result = map_service.roll_dice(user.user_id)
    if not roll_result then
        logger.error("Failed to roll dice for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CRollDiceResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            "Failed to roll dice", 
            message.MessageID.G2C_ROLL_DICE_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        dice_value = roll_result.dice_value,
        from_position = roll_result.from_position,
        to_position = roll_result.to_position,
        event_ids = {}  -- 初始化空数组
    }

    -- 转换事件数据为新的格式
    for _, event_info in ipairs(roll_result.event_ids) do
        -- 确保 is_random_event 字段存在
        local is_random = false
        if event_info.is_random_event ~= nil then
            is_random = event_info.is_random_event == true or event_info.is_random_event == 1
        end
        
        table.insert(response_data.event_ids, {
            event_id = event_info.event_id,
            cell_id = event_info.cell_id,
            is_random_event = is_random
        })
    end

    -- 返回成功响应
    local response = message_helper.create_success_response(
        base_request,
        "command.G2CRollDiceResponse",
        response_data,
        message.MessageID.G2C_ROLL_DICE_RESPONSE)
        
    logger.debug("Roll dice response: %s", utils.table_to_string(response_data))
    return response
end

return M 