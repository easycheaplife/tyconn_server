-- game.lua
-- 游戏服务
-- 负责处理游戏逻辑
-- 接收来自 agent 的消息，处理后返回结果

local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

-- 用户管理表
local users = {}  -- fd -> {agent, node}

-- 消息处理函数表
local handlers = {
    -- 处理 hello 命令
    hello = function(_, msg)
        return string.format("Hello %s!", msg)
    end,
    
    -- 处理 echo 命令
    echo = function(_, msg)
        return msg
    end
}

-- 服务命令处理表
local CMD = {}

-- 处理客户端消息
function CMD.client_message(source, client_fd, msg)
    -- 新客户端连接，记录到用户表
    if not users[client_fd] then
        users[client_fd] = {
            agent = source,
            node = "gate"  -- 记录 agent 所在的节点
        }
    end
    
    -- 尝试解析消息
    local cmd, params = string.match(msg, "([^|]+)|?(.*)")
    cmd = cmd or msg
    params = params or ""
    
    logger.debug("Game(%d) received command from fd=%d: %s, params: %s", 
        skynet.self(), client_fd, cmd, params)
    
    -- 查找并执行对应的处理函数
    local handler = handlers[cmd]
    if handler then
        local response = handler(client_fd, params)
        if response then
            logger.debug("Game(%d) sending response to fd=%d: %s", 
                skynet.self(), client_fd, response)
            -- 使用 cluster.send 发送消息给 agent
            cluster.send("gate", source, "client_message", response)
        end
    else
        -- 如果不是已知命令，就当作 echo 处理
        logger.debug("Game(%d) echo message from fd=%d: %s", 
            skynet.self(), client_fd, msg)
        -- 使用 cluster.send 发送消息给 agent
        cluster.send("gate", source, "client_message", msg)
    end
end

-- 处理客户端断开连接
function CMD.client_disconnect(_, client_fd)
    users[client_fd] = nil
end

-- 服务入口
skynet.start(function()
    logger.info("Game(%d) service starting", skynet.self())
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            -- 直接传递 ... 给命令处理函数
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Game(%d) unknown command: %s", skynet.self(), cmd)
        end
    end)
    
    logger.info("Game(%d) service started", skynet.self())
end) 