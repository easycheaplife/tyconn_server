local pb = require "pb"
local logger = require "logger"
local user_model = require "game.models.user"
local message_util = require "game.utils.message"

local M = {}

-- 注册处理
function M.handle(client_id, msg)
    -- 解码基础请求
    local base_request = message_util.decode_request(msg)
    if not base_request then
        return message_util.encode_response(message_util.create_error_response(
            nil,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end

    -- 解码注册请求
    local ok, request = pcall(pb.decode, "command.C2SRegisterRequest", base_request.payload)
    if not ok then
        logger.error("解码注册请求失败: %s", request)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end
    
    -- 参数验证
    if not request.username or #request.username < 3 then
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM"),
            "用户名至少需要3个字符"
        ))
    end
    
    if not request.password or #request.password < 6 then
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM"),
            "密码至少需要6个字符"
        ))
    end
    
    -- 创建用户
    local user, err = user_model.create_user(
        request.username,
        request.password,
        request.nickname,
        request.avatar
    )
    
    if not user then
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_USERNAME_EXISTS"),
            err
        ))
    end
    
    -- 构造用户信息
    local user_info = {
        user_id = user.user_id,
        nickname = user.nickname,
        level = user.level,
        exp = user.exp,
        vip_level = user.vip_level,
        gold = user.gold,
        diamond = user.diamond,
        avatar = user.avatar,
        register_time = user.register_time,
        last_login = user.last_login
    }
    
    -- 创建注册响应
    local register_response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "注册成功",
        user_info = user_info
    }
    
    -- 编码注册响应
    local ok, payload = pcall(pb.encode, "command.S2CRegisterResponse", register_response)
    if not ok then
        logger.error("编码注册响应失败: %s", payload)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "系统错误"
        ))
    end
    
    -- 记录用户信息
    user_model.add_user(client_id, user_info)
    
    -- 创建并返回基础响应
    return message_util.encode_response(message_util.create_success_response(
        base_request.session,
        payload
    ))
end

return M 