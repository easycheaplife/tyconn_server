local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local user_mgr = require "game.user_mgr"
local db_client = require "game.db_client"  -- 添加 db_client

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling card bag info request from client %d", client_id)
    
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return message.create_error_response(0, 
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO"), 
            "Invalid proto")
    end

    -- 解码请求
    local ok, request = pcall(pb.decode, "command.C2GUserCardBagRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode card bag request: %s", request)
        return message.create_error_response(base_request.session, 
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PROTO"), 
            "Invalid proto")
    end

    logger.debug("Processing card bag request with token: %s", request.token)

    -- 验证Token并获取用户信息
    local result = user_mgr.verify_token_and_get_user(request.token)
    if result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Invalid token for client: %d", client_id)
        return message.create_error_response(base_request.session, 
            result.code, result.message)
    end

    -- 使用 db_client 获取用户卡包
    local cards = db_client.get_user_cards(result.user.user_id)
    if not cards then
        logger.error("Failed to get cards for user: %d", result.user.user_id)
        return message.create_error_response(base_request.session, 
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"), 
            "Failed to get user cards")
    end

    -- 创建响应
    local response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        cards = cards or {}
    }

    -- 创建成功响应
    local base_response = message.create_base_response(
        base_request.session,  -- 使用请求中的session
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "Success",
        pb.encode("command.G2CUserCardBagResponse", response)
    )

    -- 编码并返回响应
    return message.encode_response(base_response)
end

return M 