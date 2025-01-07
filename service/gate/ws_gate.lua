-- ws_gate.lua
-- WebSocket 网关服务
-- 负责管理 WebSocket 连接和消息转发
-- 为每个客户端连接创建一个 agent 服务

local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"

-- 连接管理表
local connection = {}  -- fd -> agent
local game_service    -- 游戏服务句柄

-- WebSocket 事件处理器
local handler = {}

-- 处理新的 WebSocket 连接
-- @param fd: 连接的文件描述符
function handler.connect(fd)
    logger.info("Gate(%d) new client connected, fd=%d", skynet.self(), fd)
    
    -- 为新连接创建代理服务
    local agent = skynet.newservice("ws_agent")
    connection[fd] = agent
    
    -- 启动代理服务
    local ok, err = pcall(skynet.call, agent, "lua", "start", { 
        fd = fd,
        game = game_service,
        gate = skynet.self()
    })
    
    -- 处理启动失败的情况
    if not ok then
        logger.error("Gate(%d) failed to start agent for fd=%d: %s", skynet.self(), fd, err)
        connection[fd] = nil
        skynet.kill(agent)
        return
    end
    
    logger.info("Gate(%d) agent(%d) started for fd=%d", skynet.self(), agent, fd)
end

-- 处理 WebSocket 消息
-- @param fd: 连接的文件描述符
-- @param msg: 消息内容
-- @param msg_type: 消息类型
function handler.message(fd, msg, msg_type)
    local agent = connection[fd]
    if agent then
        logger.debug("Gate(%d) received message from fd=%d: %s", skynet.self(), fd, msg)
        skynet.send(agent, "lua", "message", msg, msg_type)
    else
        logger.error("Gate(%d) no agent for fd=%d", skynet.self(), fd)
    end
end

-- 处理连接关闭
-- @param fd: 连接的文件描述符
function handler.close(fd)
    local agent = connection[fd]
    if agent then
        logger.info("Gate(%d) client disconnected, fd=%d", skynet.self(), fd)
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    end
end

-- 服务命令处理表
local CMD = {}

-- 启动网关服务
-- @param conf: 配置信息，包含 port, game 等
-- @return: true 表示启动成功
function CMD.start(conf)
    game_service = conf.game
    local id = socket.listen("0.0.0.0", conf.port)
    socket.start(id, function(fd, addr)
        logger.info("Gate(%d) new connection from %s, fd=%d", skynet.self(), addr, fd)
        websocket.accept(fd, handler, "ws", addr)
    end)
    logger.info("Gate(%d) started on port %d", skynet.self(), conf.port)
    return true
end

-- 发送消息给客户端
-- @param fd: 连接的文件描述符
-- @param msg: 消息内容
function CMD.send_message(fd, msg)
    if connection[fd] then
        logger.debug("Gate(%d) sending message to fd=%d: %s", skynet.self(), fd, msg)
        local ok, err = pcall(websocket.write, fd, msg)
        if not ok then
            logger.error("Gate(%d) failed to send message to fd=%d: %s", skynet.self(), fd, err)
        end
    else
        logger.error("Gate(%d) no connection for fd=%d", skynet.self(), fd)
    end
end

-- 服务入口
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(subcmd, ...)))
        elseif cmd == "socket" then
            handler[subcmd](...)
        end
    end)
end) 