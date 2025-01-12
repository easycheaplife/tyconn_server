local pb = require "pb"
local logger = require "logger"
local user_model = require "game.models.user"
local message_util = require "game.utils.message"
local utils = require "utils"

local M = {}

-- 登录处理
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
    
    -- 打印原始请求数据
    logger.debug("Raw request payload (hex): %s", pb.tohex(msg))

    -- 解码登录请求
    local ok, request = pcall(pb.decode, "command.C2SLoginRequest", base_request.payload)
    if not ok then
        logger.error("解码登录请求失败: %s", request)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            "无效的请求格式"
        ))
    end
    
    -- 打印解码后的请求数据
    logger.debug("Decoded login request: account=%s, password=%s", 
        request.account, 
        request.password
    )

    -- 获取或创建用户
    local user, err, is_new_user = user_model.get_or_create_user(request.account, request.password)
    if not user then
        logger.error("Login failed - error: %s", err)
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_WRONG_PASSWORD"),
            err
        ))
    end
    
    -- 记录用户会话
    user_model.add_user(client_id, user)
    
    -- 更新最后登录时间
    user.last_login = os.time()
    user_model.update_user(user)
    
    -- 创建登录响应
    local login_response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = is_new_user and "账号创建成功" or "登录成功",
        token = "token_" .. user.user_id,
        user_info = {
            user_id = user.user_id,
            username = user.username,
            nickname = user.nickname,
            level = user.level,
            exp = user.exp,
            vip_level = user.vip_level,
            gold = user.gold,
            diamond = user.diamond,
            avatar = user.avatar,
            register_time = user.register_time,
            last_login = user.last_login
        },
        isNewUser = is_new_user
    }
    
    -- 编码登录响应
    local ok, payload = pcall(pb.encode, "command.S2CLoginResponse", login_response)
    if not ok then
        logger.error("编码登录响应失败: %s", payload)
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