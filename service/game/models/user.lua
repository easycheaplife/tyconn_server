local pb = require "pb"

local M = {}

-- 用户数据存储
local users = {}

-- 创建用户信息
function M.create_user_info(user_id, nickname)
    return {
        user_id = user_id,            -- int64
        nickname = nickname,          -- string
        level = 1,                    -- int32
        exp = 0,                      -- int64
        vip_level = 0,               -- int32
        gold = 1000,                 -- int64
        diamond = 100,               -- int64
        avatar = "default.png",      -- string
        register_time = os.time(),   -- int64
        last_login = os.time()       -- int64
    }
end

-- 创建错误响应
function M.create_error_response(code, message)
    return pb.encode("command.S2CLoginResponse", {
        code = pb.enum("common.ErrorCode", code),
        message = message
    })
end

-- 添加用户
function M.add_user(client_id, user_info)
    users[client_id] = {
        user_info = user_info
    }
end

-- 获取用户
function M.get_user(client_id)
    return users[client_id]
end

-- 删除用户
function M.remove_user(client_id)
    users[client_id] = nil
end

return M 