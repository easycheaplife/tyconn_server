-- ws_agent.lua
-- WebSocket 代理服务
-- 负责处理单个客户端连接的消息收发
-- 作为 gate 和 game 服务之间的中间层

local skynet = require "skynet"
local logger = require "logger"

-- 服务句柄
local gate        -- gate 服务句柄
local client_fd   -- 客户端连接的文件描述符
local game        -- game 服务句柄

local CMD = {}

-- 启动代理服务
-- @param conf: 配置信息，包含 fd, game, gate
function CMD.start(conf)
    client_fd = conf.fd
    game = conf.game
    gate = conf.gate
    logger.info("Agent(%d) started for client fd=%d", skynet.self(), client_fd)
end

-- 处理客户端断开连接
function CMD.disconnect()
    logger.info("Agent(%d) client disconnected, fd=%d", skynet.self(), client_fd)
    skynet.send(game, "lua", "client_disconnect", client_fd)
    skynet.exit()
end

-- 处理客户端消息
-- @param msg: 消息内容
-- @param msg_type: 消息类型
function CMD.message(msg, msg_type)
    logger.debug("Agent(%d) received message from fd=%d: %s", skynet.self(), client_fd, msg)
    skynet.send(game, "lua", "client_message", client_fd, msg, msg_type)
end

-- 发送消息给客户端
-- @param msg: 消息内容
function CMD.send_client(msg)
    logger.debug("Agent(%d) sending message to fd=%d: %s", skynet.self(), client_fd, msg)
    skynet.send(gate, "lua", "send_message", client_fd, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Agent(%d) unknown command: %s", skynet.self(), cmd)
        end
    end)
end) 