local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local handler_helper = require "game.handlers.handler_helper"
local item = require "game.models.item"
local user = require "game.models.user"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling bag info request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUserItemsRequest")
    if not base_request then
        return request  -- 错误响应
    end

    -- 获取用户物品列表
    local items, err = item.get_user_items(user.user_id)
    if not items then
        logger.error("Failed to get items for user %d: %s", user.user_id, err)
        return handler_helper.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
            "Failed to get items")
    end

    -- 构造响应
    local result = {
        items = items
    }

    return handler_helper.create_success_response(
        base_request,
        "command.G2CBagInfoResponse",
        result,
        pb.enum("common.MessageID", "G2C_BAG_INFO_RESPONSE"))
end

return M 