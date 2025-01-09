-- ws_agent.lua
-- WebSocket 代理服务
-- 负责处理单个客户端连接的消息收发
-- 作为 gate 和 game 服务之间的中间层

local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

-- 服务句柄
local gate        -- gate 服务句柄
local client_fd   -- 客户端连接的文件描述符
local game        -- game 服务句柄
local game_node   -- game 服务节点

local CMD = {}

-- 启动代理服务
-- @param conf: 配置信息，包含 fd, game, game_node, gate
function CMD.start(conf)
    client_fd = conf.fd
    game = conf.game
    game_node = conf.game_node
    gate = conf.gate    -- 保存 gate 服务句柄
    logger.info("Agent(%d) started for client %d", skynet.self(), client_fd)
end

-- 处理客户端断开连接
function CMD.disconnect()
    cluster.send(game_node, game, "client_disconnect", skynet.self(), client_fd)
    skynet.exit()
end

-- 处理客户端消息
-- @param msg: 消息内容
function CMD.message(msg, msg_type)
    -- 确保消息是字符串类型
    if type(msg) == "number" then
        msg = tostring(msg)
    end
    
    -- 转发消息到游戏服务
    if msg_type == "binary" then
        -- 处理二进制消息
        logger.debug("Agent(%d) received binary message from fd=%d, length=%d", 
            skynet.self(), client_fd, #msg)
    else
        -- 处理文本消息
        logger.debug("Agent(%d) received text message from fd=%d: %s", 
            skynet.self(), client_fd, msg)
    end
    
    -- 使用 ... 展开参数，确保参数顺序正确
    cluster.send(game_node, game, "client_message", skynet.self(), client_fd, msg)
end

-- 发送消息给客户端
-- @param msg: 消息内容
function CMD.client_message(msg)
    -- 确保消息是字符串类型
    if type(msg) == "number" then
        msg = tostring(msg)
    end
    -- 发送消息给客户端
    skynet.send(gate, "lua", "send_message", client_fd, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Agent(%d) unknown command: %s", skynet.self(), cmd)
        end
    end)
end) 