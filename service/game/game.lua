-- game.lua
-- 游戏服务
-- 负责处理游戏逻辑
-- 接收来自 agent 的消息，处理后返回结果

local skynet = require "skynet"
local logger = require "logger"

-- 用户管理表
local users = {}  -- fd -> {agent = agent}

-- 消息处理函数表
local handlers = {
    -- 处理 hello 命令
    -- @param fd: 客户端连接标识
    -- @param msg: 消息参数
    -- @return: 响应消息
    hello = function(fd, msg)
        logger.debug("Game(%d) handling hello command from fd=%d: %s", skynet.self(), fd, msg)
        return string.format("Hello %s!", msg)
    end,
    
    -- 处理 echo 命令
    -- @param fd: 客户端连接标识
    -- @param msg: 消息内容
    -- @return: 原样返回消息内容
    echo = function(fd, msg)
        logger.debug("Game(%d) handling echo command from fd=%d: %s", skynet.self(), fd, msg)
        return msg
    end
}

-- 服务命令处理表
local CMD = {}

-- 处理客户端消息
-- @param source: 消息来源（agent 服务）
-- @param fd: 客户端连接标识
-- @param msg: 消息内容
-- @param msg_type: 消息类型
function CMD.client_message(source, fd, msg, msg_type)
    -- 新客户端连接，记录到用户表
    if not users[fd] then
        users[fd] = {agent = source}
        logger.info("Game(%d) new client connected from agent(%d), fd=%d", 
            skynet.self(), source, fd)
    end
    
    -- 处理文本消息
    if msg_type == "text" then
        -- 解析命令和参数
        local cmd, params = string.match(msg, "([^|]+)|?(.*)")
        logger.debug("Game(%d) received command from fd=%d: %s, params: %s", 
            skynet.self(), fd, cmd, params)
        
        -- 查找并执行对应的处理函数
        local handler = handlers[cmd]
        if handler then
            local response = handler(fd, params)
            if response then
                logger.debug("Game(%d) sending response to fd=%d: %s", 
                    skynet.self(), fd, response)
                skynet.send(source, "lua", "send_client", response)
            end
        else
            logger.error("Game(%d) unknown command from fd=%d: %s", 
                skynet.self(), fd, cmd)
        end
    end
end

-- 处理客户端断开连接
-- @param _: 消息来源（不使用）
-- @param fd: 客户端连接标识
function CMD.client_disconnect(_, fd)
    if users[fd] then
        logger.info("Game(%d) client disconnected, fd=%d", skynet.self(), fd)
        users[fd] = nil
    end
end

-- 服务入口
skynet.start(function()
    logger.info("Game(%d) service starting", skynet.self())
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(source, ...)))
        else
            logger.error("Game(%d) unknown command: %s", skynet.self(), cmd)
        end
    end)
    
    logger.info("Game(%d) service started", skynet.self())
end) 