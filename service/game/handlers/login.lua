local pb = require "pb"
local logger = require "logger"
local user_model = require "game.models.user"

local M = {}

-- 登录处理
function M.handle(client_id, msg)
    -- 解码登录请求
    local ok, request = pcall(pb.decode, "login.C2SLoginRequest", msg)
    if not ok then
        logger.error("解码登录请求失败: %s", request)
        return user_model.create_error_response("ERROR_CODE_SYSTEM_ERROR", "无效的请求格式")
    end
    
    -- 验证账号密码
    if request.account == "test" and request.password == "123456" then
        -- 创建用户信息
        local user_info = user_model.create_user_info(10001, "测试账号")
        
        logger.debug("user_info: %s", table.concat({
            string.format("user_id=%d", user_info.user_id),
            string.format("nickname=%s", user_info.nickname),
            string.format("level=%d", user_info.level)
        }, ", "))
        
        -- 创建登录响应
        local response = {
            code = pb.enum("login.ErrorCode", "ERROR_CODE_SUCCESS"),
            message = "登录成功",
            user_info = user_info,
            token = "dummy_token_" .. client_id
        }
        
        -- 记录用户信息
        user_model.add_user(client_id, user_info)
        
        -- 编码并返回响应
        local ok, encoded = pcall(pb.encode, "login.S2CLoginResponse", response)
        if not ok then
            logger.error("编码登录响应失败: %s", encoded)
            return user_model.create_error_response("ERROR_CODE_SYSTEM_ERROR", "系统错误")
        end
        return encoded
    else
        -- 登录失败响应
        return user_model.create_error_response("ERROR_CODE_WRONG_PASSWORD", "账号或密码错误")
    end
end

return M 