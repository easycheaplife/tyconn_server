local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"

local connection = {}  -- fd -> agent
local game_service

local handler = {}

function handler.connect(fd)
    logger.info("Gate(%d) new client connected, fd=%d", skynet.self(), fd)
    local agent = skynet.newservice("ws_agent")
    connection[fd] = agent
    
    local ok, err = pcall(skynet.call, agent, "lua", "start", { 
        fd = fd,
        game = game_service,
        gate = skynet.self()
    })
    
    if not ok then
        logger.error("Gate(%d) failed to start agent for fd=%d: %s", skynet.self(), fd, err)
        connection[fd] = nil
        skynet.kill(agent)
        return
    end
    
    logger.info("Gate(%d) agent(%d) started for fd=%d", skynet.self(), agent, fd)
end

function handler.message(fd, msg, msg_type)
    local agent = connection[fd]
    if agent then
        logger.debug("Gate(%d) received message from fd=%d: %s", skynet.self(), fd, msg)
        skynet.send(agent, "lua", "message", msg, msg_type)
    else
        logger.error("Gate(%d) no agent for fd=%d", skynet.self(), fd)
    end
end

function handler.close(fd)
    local agent = connection[fd]
    if agent then
        logger.info("Gate(%d) client disconnected, fd=%d", skynet.self(), fd)
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    end
end

local CMD = {}

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