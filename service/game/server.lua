local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"

-- 加载消息处理模块
local handlers = {
    login = require "game.handlers.login"
}

-- 命令处理模块
local CMD = {}

function CMD.client_message(source, client_id, msg)
    -- 解析消息类型和内容
    local cmd, params = string.match(msg, "([^|]+)|?(.*)")
    cmd = cmd or msg
    
    -- 处理消息
    local handler = handlers[cmd]
    if handler then
        local response = handler.handle(client_id, params)
        if response then
            cluster.send("gate1", source, "client_message", response)
        end
    end
end

function CMD.client_disconnect(_, client_id)
    local user_model = require "game.models.user"
    user_model.remove_user(client_id)
end

-- 服务入口
skynet.start(function()
    logger.info("Game server starting...")
    
    -- 加载协议文件
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return
    end
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
    
    logger.info("Game server started")
end)