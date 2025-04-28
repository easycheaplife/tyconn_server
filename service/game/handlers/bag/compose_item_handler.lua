local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local bag_service = require "services.bag_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local utils = require "utils"
local config_service = require "services.config_service"
local error = require "error"  
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling compose item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GComposeItemRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CComposeItemResponse", 
            error_code, 
            error_message, 
            message.MessageID.G2C_COMPOSE_ITEM_RESPONSE)
    end

    -- 验证参数
    if not request.target_id then
        return message_helper.create_error_response(
            base_request,
            "command.G2CComposeItemResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAM,
            "Invalid parameters: target_id is required",
            message.MessageID.G2C_COMPOSE_ITEM_RESPONSE)
    end
    
    -- 调用背包服务进行物品合成
    local ok, result, new_item, remain_items = bag_service.compose_item(
        user.user_id, 
        request.target_id
    )
    
    if not ok then
        logger.error("Failed to compose item for user: %d, error: %s", user.user_id, result)
        return message_helper.create_error_response(
            base_request,
            "command.G2CComposeItemResponse",
            error.ErrorCode.ERROR_CODE_COMPOSE_ITEM_FAILED,
            result,
            message.MessageID.G2C_COMPOSE_ITEM_RESPONSE)
    end

    logger.info("Compose item success - user_id: %d, target_id: %d", 
        user.user_id, request.target_id)
    
    -- 构造返回物品信息
    local new_item_info = new_item and {
        item_id = new_item.item_id,
        count = new_item.count,
        slot = new_item.slot_index,
        bag_type = new_item.bag_type
    } or nil
    
    local remain_items_info = {}
    for _, item in ipairs(remain_items or {}) do
        table.insert(remain_items_info, {
            item_id = item.item_id,
            count = item.count,
            slot = item.slot_index,
            bag_type = item.bag_type
        })
    end
    
    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CComposeItemResponse",
        { 
            success = true,
            new_item = new_item_info,
            remain_items = remain_items_info
        },
        message.MessageID.G2C_COMPOSE_ITEM_RESPONSE)
end

return M 