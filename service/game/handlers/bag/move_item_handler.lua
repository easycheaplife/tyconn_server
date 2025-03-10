local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local bag_service = require "services.bag_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"
local utils = require "utils"
local error = require "error"  

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling move item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GMoveItemRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CMoveItemResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_MOVE_ITEM_RESPONSE"))
    end

    -- 验证参数
    if not request.src_bag_type or not request.src_slot or not request.dst_bag_type or not request.dst_slot then
        return message.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_INVALID_PARAM,
            "command.G2CMoveItemResponse",
            "Invalid parameters: src_bag_type, src_slot, dst_bag_type, dst_slot are required",
            pb.enum("common.MessageID", "G2C_MOVE_ITEM_RESPONSE"))
    end

    -- 验证背包类型
    local valid_bag_types = {
        [pb.enum("common.BagType", "BAG_TYPE_MAIN")] = true
    }

    -- 获取背包类型的数值
    local src_bag_type = type(request.src_bag_type) == "string" 
        and pb.enum("common.BagType", request.src_bag_type) or request.src_bag_type
    local dst_bag_type = type(request.dst_bag_type) == "string" 
        and pb.enum("common.BagType", request.dst_bag_type) or request.dst_bag_type

    if not valid_bag_types[src_bag_type] or not valid_bag_types[dst_bag_type] then
        return message.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_INVALID_BAG_TYPE,
            "command.G2CMoveItemResponse",
            "Invalid bag type",
            pb.enum("common.MessageID", "G2C_MOVE_ITEM_RESPONSE"))
    end

    -- 移动数量，如果未指定则移动全部
    local count = request.count or 0
    
    -- 调用背包服务进行物品移动
    local ok, err, changed_items = bag_service.move_item(
        user.user_id, 
        src_bag_type, 
        request.src_slot, 
        dst_bag_type, 
        request.dst_slot,
        count
    )
    
    if not ok then
        logger.error("Failed to move item for user: %d, error: %s", user.user_id, err)
        return message.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_MOVE_ITEM_FAILED,
            "command.G2CMoveItemResponse",
            err,
            pb.enum("common.MessageID", "G2C_MOVE_ITEM_RESPONSE"))
    end

    logger.info("Move item success - user_id: %d, from: %d,%d to: %d,%d", 
        user.user_id, src_bag_type, request.src_slot, dst_bag_type, request.dst_slot)
    
    -- 构造返回物品信息
    local items_response = {}
    for _, item in ipairs(changed_items or {}) do
        table.insert(items_response, {
            item_id = item.item_id,
            count = item.count,
            slot = item.slot_index,
            bag_type = item.bag_type
        })
    end
    
    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CMoveItemResponse",
        { changed_items = items_response },
        pb.enum("common.MessageID", "G2C_MOVE_ITEM_RESPONSE"))
end

return M 