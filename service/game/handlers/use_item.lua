local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local handler_helper = require "game.handlers.handler_helper"
local item = require "game.models.item"
local user = require "game.models.user"
local utils = require "utils"
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling use item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUseItemRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message.create_error_response(
            base_request,
            error_code,
            "command.G2CUseItemResponse",
            nil,
            pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
    end

    -- 使用物品
    local ok, changed_items = item.use_item(user.user_id, request.item_id, request.count)
    if not ok then
        logger.error("Failed to use item: %s", changed_items)
        return message.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAMS"),
            "command.G2CUseItemResponse",
            nil,
            pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
    end

    -- 构造响应
    local result = {
        items = changed_items
    }

    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CUseItemResponse",
        result,
        pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
end

return M 