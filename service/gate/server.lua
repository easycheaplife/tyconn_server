local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"

local connections = {}  -- client_id -> agent
local game_services    -- 所有游戏服务
local next_game_index = 1  -- 用于轮询分配

-- 获取下一个游戏服务
local function get_next_game_service()
    local nodes = {}
    for node, service in pairs(game_services) do
        table.insert(nodes, {node = node, service = service})
    end
    table.sort(nodes, function(a, b) return a.node < b.node end)  -- 保证顺序一致
    
    local game = nodes[next_game_index]
    next_game_index = next_game_index % #nodes + 1
    if next_game_index == 0 then next_game_index = 1 end
    
    return game.service, game.node
end

local handler = {}

function handler.connect(client_id)
    local game_service, game_node = get_next_game_service()
    local agent = skynet.newservice("gate/agent")
    connections[client_id] = agent
    
    skynet.call(agent, "lua", "start", {
        client_id = client_id,
        game = game_service,
        game_node = game_node,
        gateway = skynet.self()
    })
    
    logger.debug("New client %d connected, assigned to game node: %s", client_id, game_node)
end

function handler.message(client_id, msg, msg_type)
    logger.debug("Received message type: %s from client %d", msg_type or "text", client_id)
    local agent = connections[client_id]
    if agent then
        if msg_type == "binary" then
            -- 处理二进制消息
            skynet.send(agent, "lua", "message", msg)
        else
            -- 处理文本消息
            skynet.send(agent, "lua", "message", msg)
        end
    end
end

function handler.close(client_id)
    local agent = connections[client_id]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        connections[client_id] = nil
        logger.debug("Client %d disconnected", client_id)
    end
end

local CMD = {}

function CMD.start(conf)
    game_services = conf.game_services
    local port = conf.port
    
    local id = socket.listen("0.0.0.0", port)
    socket.start(id, function(fd, addr)
        websocket.accept(fd, handler, "ws", addr)
    end)
    
    logger.info("WebSocket server started on ws://0.0.0.0:%d", port)
    return true
end

function CMD.send_message(client_id, msg)
    if connections[client_id] then
        websocket.write(client_id, msg, "binary")
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(subcmd, ...)))
        elseif cmd == "socket" then
            handler[subcmd](...)
        else
            logger.error("Unknown command: %s", cmd)
        end
    end)
end)