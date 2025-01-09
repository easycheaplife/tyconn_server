local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local connections = {}
local game_service
local game_node

local handler = {}

function handler.connect(client_id)
    local agent = skynet.newservice("gate/agent")
    connections[client_id] = agent
    skynet.call(agent, "lua", "start", {
        client_id = client_id,
        game = game_service,
        game_node = game_node,
        gateway = skynet.self()
    })
end

function handler.message(client_id, msg)
    local agent = connections[client_id]
    if agent then
        skynet.send(agent, "lua", "message", msg)
    end
end

function handler.close(client_id)
    local agent = connections[client_id]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        connections[client_id] = nil
    end
end

local CMD = {}

function CMD.start(conf)
    game_service = conf.game
    game_node = conf.game_node
    local id = socket.listen("0.0.0.0", conf.port)
    socket.start(id, function(fd, addr)
        websocket.accept(fd, handler, "ws", addr)
    end)
    return true
end

function CMD.send_message(client_id, msg)
    if connections[client_id] then
        websocket.write(client_id, msg)
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