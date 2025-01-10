local pb = require "pb"
local logger = require "logger"
local user_model = require "game.models.user"
local message_util = require "game.utils.message"

local M = {}

-- 打印表内容的辅助函数
local function table_to_string(t)
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            table.insert(result, k .. "=" .. table_to_string(v))
        else
            table.insert(result, k .. "=" .. tostring(v))
        end
    end
    return "{" .. table.concat(result, ", ") .. "}"
end

-- 登录处理
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
    
    -- 验证账号密码
    if request.account == "test" and request.password == "123456" then
        -- 创建用户信息
        local user_info = user_model.create_user_info(10001, "测试账号")
        
        -- 打印调试信息
        logger.debug("user_info: %s", table_to_string(user_info))
        
        -- 创建登录响应
        local login_response = {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
            message = "登录成功",
            user_info = user_info,
            token = "dummy_token_" .. client_id
        }
        
        -- 记录用户信息
        user_model.add_user(client_id, user_info)
        
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
        
        -- 创建并返回基础响应
        return message_util.encode_response(message_util.create_success_response(
            base_request.session,
            payload
        ))
    else
        -- 登录失败响应
        return message_util.encode_response(message_util.create_error_response(
            base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_WRONG_PASSWORD"),
            "账号或密码错误"
        ))
    end
end

return M 