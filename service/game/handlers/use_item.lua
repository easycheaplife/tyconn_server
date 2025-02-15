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
    local ok, base_request, account = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUseItemRequest")
    if not ok then
        return base_request
    end

    -- 解码请求
    local request = pb.decode("command.C2GUseItemRequest", base_request.payload)
    logger.debug("Use item request: %s", utils.table_to_string(request))

    -- 获取用户信息
    local user_info = user.get_user(account)
    if not user_info then
        return handler_helper.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_USER_NOT_FOUND"),
            "用户不存在")
    end

    -- 使用物品
    local ok, result = item.use_item(user_info.user_id, request.item_id, request.count)
    if not ok then
        return handler_helper.create_error_response(
            base_request,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_OPERATION"),
            result)
    end

    -- 返回使用结果
    local response = {
        item = result
    }

    return handler_helper.create_success_response(
        base_request,
        "command.G2CUseItemResponse",
        response,
        pb.enum("common.MessageID", "G2C_USE_ITEM_RESPONSE"))
end

return M 