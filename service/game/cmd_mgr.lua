local skynet = require "skynet"
local logger = require "logger"
local message_mgr = require "game.message_mgr"
local user_service = require "services.user_service"
local session = require "services.session_service"

local M = {}
local CMD = {}

-- 处理客户端消息
function CMD.client_message(source, client_id, msg, gate_node)
    logger.debug("Received message from client %d via gate %s", client_id, gate_node)
    message_mgr.handle_message(source, client_id, msg, gate_node)
end

-- 处理客户端断开连接
function CMD.client_disconnect(_, client_id)
    logger.info("Client disconnected: %d", client_id)
    session.remove_user(client_id)
end

-- 获取用户信息
function CMD.get_user(token)
    return user_service.get_user(token)
end

-- 服务启动
function CMD.start(conf)
    -- 打印环境变量
    logger.debug("Environment variables:")
    logger.debug("  jwt_secret = %s", conf.jwt_secret)

    return true
end

-- 更新用户信息
function CMD.update_user(user)
    if not user or not user.account then
        return false, "Invalid user info"
    end
    
    local ok, err = user.update_user(user)
    if not ok then
        logger.error("Failed to update user: %s", err)
        return false, err
    end
    
    return true
end

-- 初始化命令管理器
function M.init()
    -- 注册消息处理函数
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", cmd)
        end
    end)
    
    return true
end

-- 获取命令处理函数
function M.get_handler(cmd)
    return CMD[cmd]
end

return M 