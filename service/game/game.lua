local skynet = require "skynet"
local logger = require "logger"  -- 引入日志模块
local log = logger.log          -- 简化调用

local game = {}
local users = {}  -- fd -> user_info
local CMD = {}
local HANDLER = {}  -- 负载均衡服务

-- 消息处理函数
function HANDLER.hello(fd, msg)
    return string.format("Hello %s!", msg)
end

function HANDLER.echo(fd, msg)
    return msg
end

-- 处理客户端消息
function CMD.client_message(source, fd, msg, msg_type)
    log(string.format("Game(%d) received message from agent(%d), fd=%d, type=%s", 
        skynet.self(), source, fd, msg_type))
    
    local user = users[fd]
    if not user then
        user = {
            fd = fd,
            agent = source,
        }
        users[fd] = user
        log(string.format("Game(%d) new client connected from agent(%d), fd=%d", 
            skynet.self(), user.agent, fd))
    end
    
    -- 解析消息
    if msg_type == "text" then
        -- 假设消息格式为: "cmd|params"
        local cmd, params = string.match(msg, "([^|]+)|?(.*)")
        log(string.format("Game(%d) parse message: cmd=%s, params=%s", 
            skynet.self(), cmd, params))
        
        local f = HANDLER[cmd]
        if f then
            -- 处理消息并返回结果
            local response = f(fd, params)
            if response then
                -- 通过agent返回给客户端
                log(string.format("Game(%d) send response to agent(%d): %s", 
                    skynet.self(), user.agent, response))
                skynet.send(user.agent, "lua", "send_client", response)
            end
        else
            log(string.format("Game(%d) unknown command: %s", skynet.self(), cmd))
        end
    end
end

-- 客户端断开连接
function CMD.client_disconnect(source, fd)
    local user = users[fd]
    if user then
        log(string.format("Game(%d) client disconnect, fd=%d, agent=%d", 
            skynet.self(), fd, user.agent))
    end
    users[fd] = nil
end

function CMD.start()
    log(string.format("Game(%d) starting", skynet.self()))
    
    -- 这里可以添加游戏服务的初始化逻辑
    
    log(string.format("Game(%d) started successfully", skynet.self()))
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            if cmd == "client_message" or cmd == "client_disconnect" then
                -- 这些命令需要 source 参数
                skynet.ret(skynet.pack(f(source, ...)))
            else
                -- 其他命令直接传参
                skynet.ret(skynet.pack(f(...)))
            end
        else
            log(string.format("Game(%d) unknown command: %s", skynet.self(), cmd))
        end
    end)
end)

return game 