local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local handler_helper = require "game.handlers.handler_helper"
local item = require "game.models.item"
local user = require "game.models.user"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling use item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUseItemRequest")
    if not base_request then
        return request  -- 错误响应
    end

    -- 使用物品
    local ok, changed_items = item.use_item(user.user_id, request.item_id, request.count)
    if not ok then
        logger.error("Failed to use item: %s", changed_items)
        return handler_helper.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAMS"),
            changed_items)
    end

    -- 构造响应
    local result = {
        items = changed_items
    }

    -- 返回成功响应
    return handler_helper.create_success_response(
        base_request,
        "command.G2CUseItemResponse",
        result,
        pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
end

return M 