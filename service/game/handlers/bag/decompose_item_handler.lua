local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local bag_service = require "services.bag_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling decompose item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GDecomposeItemRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CDecomposeItemResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_DECOMPOSE_ITEM_RESPONSE"))
    end

    -- 验证参数
    if not request.target_id then
        return message.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM"),
            "command.G2CDecomposeItemResponse",
            "Invalid parameters: target_id is required",
            pb.enum("common.MessageID", "G2C_DECOMPOSE_ITEM_RESPONSE"))
    end
    
    -- 调用背包服务进行物品分解
    local ok, err, result_items = bag_service.decompose_item(
        user.user_id, 
        request.target_id
    )
    
    if not ok then
        logger.error("Failed to decompose item for user: %d, error: %s", user.user_id, err)
        return message.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_DECOMPOSE_ITEM_FAILED"),
            "command.G2CDecomposeItemResponse",
            err,
            pb.enum("common.MessageID", "G2C_DECOMPOSE_ITEM_RESPONSE"))
    end

    logger.info("Decompose item success - user_id: %d", user.user_id)
    
    -- 构造返回物品信息
    local result_items_info = {}
    for _, item in ipairs(result_items or {}) do
        table.insert(result_items_info, {
            item_id = item.item_id,
            count = item.count,
            slot = item.slot_index,
            bag_type = item.bag_type
        })
    end
    
    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CDecomposeItemResponse",
        { 
            result_items = result_items_info
        },
        pb.enum("common.MessageID", "G2C_DECOMPOSE_ITEM_RESPONSE"))
end

return M 