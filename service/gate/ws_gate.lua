local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"
local log = logger.log

local connection = {}  -- fd -> agent
local watchdog
local game_service

local handler = {}

function handler.connect(fd)
    log("Gate(%d) new client connect, fd=%d", skynet.self(), fd)
    local agent = skynet.newservice("ws_agent")
    connection[fd] = agent
    
    skynet.call(agent, "lua", "start", { 
        fd = fd,
        game = game_service,
        gate = skynet.self()
    })
end

function handler.message(fd, msg, msg_type)
    local agent = connection[fd]
    if agent then
        skynet.send(agent, "lua", "message", msg, msg_type)
    end
end

function handler.close(fd)
    local agent = connection[fd]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    end
end

local CMD = {}

function CMD.start(conf)
    watchdog = conf.watchdog
    game_service = conf.game
    local port = conf.port
    
    local id = socket.listen("0.0.0.0", port)
    socket.start(id, function(fd, addr)
        websocket.accept(fd, handler, "ws", addr)
    end)
    
    return true
end

function CMD.send_message(fd, msg)
    local agent = connection[fd]
    if agent then
        websocket.write(fd, msg)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(subcmd, ...)))
        elseif cmd == "socket" then
            local f = handler[subcmd]
            f(...)
        end
    end)
end) 