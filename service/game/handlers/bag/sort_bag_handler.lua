local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local bag_service = require "services.bag_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local utils = require "utils"
local error = require "error"  
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling sort bag request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GSortBagRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CSortBagResponse", 
            error_code, 
            error_message, 
            message.MessageID.G2C_SORT_BAG_RESPONSE)
    end

    -- 验证参数
    if not request.bag_type or not request.sort_rule then
        return message_helper.create_error_response(
            base_request,
            "command.G2CSortBagResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAM,
            "Invalid parameters: bag_type and sort_rule are required",
            message.MessageID.G2C_SORT_BAG_RESPONSE)
    end

    -- 验证背包类型
    local valid_bag_types = {
        [pb.enum("common.BagType", "BAG_TYPE_MAIN")] = true
    }

    -- 获取bag_type的数值
    local bag_type
    if type(request.bag_type) == "string" then
        bag_type = pb.enum("common.BagType", request.bag_type)
    else
        bag_type = request.bag_type
    end

    if not bag_type or not valid_bag_types[bag_type] then
        return message_helper.create_error_response(
            base_request,
            "command.G2CSortBagResponse",
            error.ErrorCode.ERROR_CODE_INVALID_BAG_TYPE,
            string.format("Invalid bag type: %s", tostring(request.bag_type)),
            message.MessageID.G2C_SORT_BAG_RESPONSE)
    end

    -- 调用背包服务进行排序
    local ok, err, items = bag_service.sort_bag(user.user_id, bag_type, request.sort_rule)
    if not ok then
        logger.error("Failed to sort bag for user: %d, error: %s", user.user_id, err)
        return message_helper.create_error_response(
            base_request,
            "command.G2CSortBagResponse",
            error.ErrorCode.ERROR_CODE_DB_ERROR,
            err,
            message.MessageID.G2C_SORT_BAG_RESPONSE)
    end

    logger.info("Sort bag success - user_id: %d, bag_type: %d, sort_rule: %d", 
        user.user_id, bag_type, request.sort_rule)
    
    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CSortBagResponse",
        { items = items },
        message.MessageID.G2C_SORT_BAG_RESPONSE)
end

return M 