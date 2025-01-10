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

    -- 验证用户名密码
    local user, err = user_model.validate_user(request.account, request.password)
    if user then
        -- 记录用户信息
        user_model.add_user(client_id, user)
        
        -- 更新最后登录时间
        user.last_login = os.time()
        user_model.update_user(user)
        
        -- 创建登录响应
        local login_response = {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
            message = "登录成功",
            token = "token_" .. user.user_id, -- 简单token生成
            user_info = {
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
            err or "账号或密码错误"
        ))
    end
end

return M 