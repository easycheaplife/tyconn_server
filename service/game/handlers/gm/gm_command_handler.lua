local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local gm_service = require "services.gm_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local error = require "error"    
local message = require "message"
local utils = require "utils"

local M = {}

local RESP_TYPE = "command.G2CGmCommandResponse"

-- 处理GM指令请求
function M.handle(client_id, msg)
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GGmCommandRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            RESP_TYPE,
            error_code, 
            error_message, 
            message.MessageID.G2C_GM_COMMAND_RESPONSE)
    end

    -- 检查GM权限
    if not user then
        logger.warn("User has no GM permission - user_id: %d", user.user_id)
        return message_helper.create_error_response(
            base_request,
            RESP_TYPE,
            error.ErrorCode.ERROR_CODE_PERMISSION_DENIED,
            "No GM permission",
            message.MessageID.G2C_GM_COMMAND_RESPONSE)
    end

    -- 执行GM命令
    local ok, result, err = gm_service.execute_command(user.user_id, request.command, request.params)
    if not ok then
        logger.error("GM command failed - user_id: %d, command: %s, error: %s, params: %s", 
            user.user_id, request.command, err or "unknown error", utils.table_to_string(request.params))
        return message_helper.create_error_response(
            base_request,
            RESP_TYPE,
            error.ErrorCode.ERROR_CODE_GM_COMMAND_FAILED,
            err or "GM command failed",
            message.MessageID.G2C_GM_COMMAND_RESPONSE)
    end

    -- 构造响应数据
    local response_data = {
        result = "success",
        message = tostring(result or "") -- 确保message是字符串
    }

    logger.info("GM command success - user_id: %d, command: %s, message: %s",
        user.user_id, request.command, tostring(result or ""))

    return message_helper.create_success_response(
        base_request,
        RESP_TYPE,
        response_data,
        message.MessageID.G2C_GM_COMMAND_RESPONSE)
end

return M 