local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"
local node_selector = require "node_selector"

local connections = {}  -- client_id -> agent
local game_nodes    -- 游戏节点列表
local next_index = 1  -- 用于轮询分配
local selector_type = skynet.getenv("node_selector") or "round_robin"

-- 获取下一个游戏节点
local function get_next_game_node(client_id)
    if selector_type == "connection_hash" then
        return node_selector.connection_hash(game_nodes, client_id)
    else  -- 默认使用轮询
        local node
        node, next_index = node_selector.round_robin(game_nodes, next_index)
        return node
    end
end

local handler = {}

function handler.connect(client_id)
    local game_node = get_next_game_node(client_id)
    local agent = skynet.newservice("gate/agent")
    connections[client_id] = agent
    
    skynet.call(agent, "lua", "start", {
        client_id = client_id,
        game_node = game_node,
        gateway = skynet.self()
    })
    
    logger.debug("New client %d connected, assigned to game node: %s (selector: %s)", 
        client_id, game_node, selector_type)
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
    game_nodes = conf.game_nodes
    table.sort(game_nodes)  -- 保证顺序一致
    
    local port = conf.port
    local id = socket.listen("0.0.0.0", port)
    socket.start(id, function(fd, addr)
        websocket.accept(fd, handler, "ws", addr)
    end)
    
    logger.info("WebSocket server started on ws://0.0.0.0:%d (selector: %s)", 
        port, selector_type)
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