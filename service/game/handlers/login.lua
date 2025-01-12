local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local user_model = require "game.models.user"
local message_util = require "game.utils.message"

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local base_request = message_util.decode_request(msg)
    if not base_request then
        logger.error("Failed to decode base request")
        return message_util.encode_response(message_util.create_error_response(
            nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end
    
    -- 解码登录请求
    local ok, request = pcall(pb.decode, "command.C2SLoginRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode login request: %s", request)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end
    
    -- 获取或创建用户
    local user, err, is_new = user_model.get_or_create_user(request.account, request.password)
    if not user then
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_WRONG_PASSWORD"),
            err or "登录失败"
        ))
    end
    
    -- 添加用户会话
    user_model.add_user(client_id, user)
    
    -- 构造用户信息
    local user_info = {
        user_id = user.user_id,
        username = user.username,
        nickname = user.nickname,
        avatar = user.avatar,
        level = user.level,
        exp = user.exp,
        vip_level = user.vip_level,
        gold = user.gold,
        diamond = user.diamond,
        register_time = user.register_time,
        last_login = user.last_login
    }
    
    -- 返回登录响应
    local response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = is_new and "注册成功" or "登录成功",
        token = "token_" .. user.user_id,
        userInfo = user_info,
        isNewUser = is_new
    }
    
    -- 编码并返回响应
    local ok, payload = pcall(pb.encode, "command.S2CLoginResponse", response)
    if not ok then
        logger.error("Failed to encode login response: %s", payload)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "系统错误"
        ))
    end
    
    return message_util.encode_response(message_util.create_success_response(
        base_request.session,
        payload
    ))
end

return M 