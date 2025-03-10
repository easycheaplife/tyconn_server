local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local item_service = require "services.item_service"
local bag_service = require "services.bag_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local utils = require "utils"
local error = require "error"  

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling expand bag request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GExpandBagRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            error_code, 
            "command.G2CExpandBagResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end

    -- 验证参数
    if not request.add_size or request.add_size <= 0 or not request.bag_type then
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_INVALID_PARAM,
            "command.G2CExpandBagResponse",
            "Invalid parameters: add_size must be positive and bag_type is required",
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end

    -- 验证背包类型
    local valid_bag_types = {
        [pb.enum("common.BagType", "BAG_TYPE_MAIN")] = true
    }

    -- 打印原始请求数据
    logger.debug("Raw request data: %s", utils.table_to_string(request))
    logger.debug("Bag type value: %s (type: %s)", 
        tostring(request.bag_type), 
        type(request.bag_type))

    -- 获取bag_type的数值
    local bag_type
    if type(request.bag_type) == "string" then
        -- 如果是字符串，尝试从枚举名称获取值
        bag_type = pb.enum("common.BagType", request.bag_type)
    else
        -- 否则直接使用数值
        bag_type = request.bag_type
    end

    if not bag_type then
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_INVALID_BAG_TYPE,
            "command.G2CExpandBagResponse",
            string.format("Invalid bag type: %s", tostring(request.bag_type)),
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end

    if not valid_bag_types[bag_type] then
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_INVALID_BAG_TYPE,
            "command.G2CExpandBagResponse",
            string.format("Invalid bag type: %s, valid types are: MAIN(1), STORAGE(2)", 
                tostring(request.bag_type)),
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end

    -- 获取当前背包信息
    local bag_info = bag_service.get_bag_info(user.user_id, bag_type)
    if not bag_info then
        logger.error("Failed to get bag info for user: %d, bag_type: %d", user.user_id, bag_type)
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_DB_ERROR,
            "command.G2CExpandBagResponse",
            nil,
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end

    -- 检查是否超过最大容量
    local max_size = bag_service.get_max_bag_size(bag_type)
    if bag_info.size + request.add_size > max_size then
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_BAG_MAX_SIZE_LIMIT,
            "command.G2CExpandBagResponse",
            nil,
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end

    -- 扩展背包
    local ok, new_size, err, items = bag_service.expand_bag(user.user_id, bag_type, request.add_size)
    if not ok then
        logger.error("Failed to expand bag for user: %d, error: %s", user.user_id, err)
        return message_helper.create_error_response(
            base_request,
            error.ErrorCode.ERROR_CODE_BAG_EXPAND_FAILED,
            "command.G2CExpandBagResponse",
            nil,
            pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
    end
    
    bag_info.size = new_size
    bag_info.items = items
    
    -- 构造响应数据
    local response_data = {
        bag = bag_info
    }

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CExpandBagResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_EXPAND_BAG_RESPONSE"))
end

return M 