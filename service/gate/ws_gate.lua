-- ws_gate.lua
-- WebSocket 网关服务
-- 负责管理 WebSocket 连接和消息转发
-- 为每个客户端连接创建一个 agent 服务

local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local connection = {}  -- fd -> agent
local game_service

local handler = {}

function handler.connect(fd)
    local agent = skynet.newservice("ws_agent")
    connection[fd] = agent
    skynet.call(agent, "lua", "start", {
        fd = fd,
        game = game_service,
        game_node = "game",
        gate = skynet.self()
    })
end

function handler.message(fd, msg)
    local agent = connection[fd]
    if agent then
        skynet.send(agent, "lua", "message", msg)
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
    game_service = conf.game
    local id = socket.listen("0.0.0.0", conf.port)
    socket.start(id, function(fd, addr)
        websocket.accept(fd, handler, "ws", addr)
    end)
    return true
end

function CMD.send_message(fd, msg)
    if connection[fd] then
        websocket.write(fd, msg)
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