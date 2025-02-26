local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"
local node_selector = require "node_selector"
local pb = require "pb"
local protoloader = require "protoloader"
local cluster = require "skynet.cluster"
local service_balancer = require "service_balancer"

local connections = {}  -- client_id -> agent
local game_nodes    -- 游戏节点列表
local next_index = 1  -- 用于轮询分配
local selector_type = skynet.getenv("node_selector") or "round_robin"
local sync_interval = 5  -- 同步间隔(秒)

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
    if connections[client_id] then
        logger.warn("Client %d already connected", client_id)
        return
    end
    
    local game_node = get_next_game_node(client_id)
    local agent = skynet.newservice("gate/agent")
    connections[client_id] = agent
    
    skynet.call(agent, "lua", "start", {
        client_id = client_id,
        game_node = game_node,
        gateway = skynet.self()
    })
    
    logger.info("New client %d connected, assigned to game node: %s", 
        client_id, game_node)
end

function handler.message(client_id, msg, msg_type)
    local agent = connections[client_id]
    if agent then
        skynet.send(agent, "lua", "message", msg)
    end
end

function handler.close(client_id)
    logger.debug("Client %d disconnected", client_id)
    local agent = connections[client_id]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        connections[client_id] = nil
    end
end

local CMD = {}

-- 同步状态到所有login节点
local function sync_status_to_login()
    -- 构建状态数据
    local status = {
        node_name = skynet.getenv("node_name"),
        service_type = "gate",
        host = skynet.getenv("websocket_host"),
        port = tonumber(skynet.getenv("websocket_port")),
        client_count = 0,
        timestamp = os.time(),
        extra = {}
    }
    
    -- 计算实际的连接数
    for _ in pairs(connections) do
        status.client_count = status.client_count + 1
    end
    
    -- 编码状态数据
    local ok, encoded = pcall(pb.encode, "internal.ServiceStatus", status)
    if not ok then
        logger.error("Failed to encode gate status: %s", encoded)
        return
    end
    
    -- 广播到所有login节点
    local results = service_balancer.broadcast("login", "update_gate_status", encoded)
    
    -- 检查结果
    for node, result in pairs(results) do
        if not result then
            logger.error("Failed to sync status to login server: node=%s", node)
        end
    end
end

function CMD.start(conf)
    -- 加载proto文件
    logger.info("Loading proto files...")
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return false
    end
    logger.info("Proto files loaded successfully")
    
    -- 打印环境变量
    logger.debug("Environment variables:")
    logger.debug("  node_name = %s", skynet.getenv("node_name"))
    logger.debug("  websocket_host = %s", skynet.getenv("websocket_host"))
    logger.debug("  websocket_port = %s", skynet.getenv("websocket_port"))

    game_nodes = conf.game_nodes
    table.sort(game_nodes)  -- 保证顺序一致
    
    local port = conf.port
    local id = socket.listen("0.0.0.0", port)
    logger.info("Starting WebSocket server on port %d", port)
    socket.start(id, function(fd, addr)
        logger.debug("New connection from %s, fd=%d", addr, fd)
        websocket.accept(fd, handler, "ws", addr)
    end)
    
    logger.info("WebSocket server started on ws://0.0.0.0:%d (selector: %s)", 
        port, selector_type)
    
    -- 初始化service_balancer
    if not service_balancer.init("login") then
        logger.error("Failed to initialize login balancer")
        skynet.exit()
        return
    end
    logger.info("Login balancer initialized")
    
    -- 立即进行第一次状态同步
    sync_status_to_login()
    
    -- 启动状态同步定时器
    skynet.fork(function()
        while true do
            sync_status_to_login()
            skynet.sleep(sync_interval * 100)  -- 转换为centiseconds
        end
    end)
    
    return true
end

function CMD.send_message(client_id, msg)
    if connections[client_id] then
        local ok, err = pcall(websocket.write, client_id, msg, "binary")
        if not ok then
            logger.error("Failed to send message to client %d: %s", client_id, err)
            -- 清理连接
            handler.close(client_id)
        end
    end
end

function CMD.client_message(source, client_id, msg)
    if not websocket.isconnected(client_id) then
        logger.error("Client %d is not connected", client_id)
        -- 清理连接
        handler.close(client_id)
        return
    end
    
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return
    end
    
    -- 验证会话信息
    if not base_request.session then
        logger.error("No session in request")
        return
    end
    
    -- 获取游戏节点
    local agent = connections[client_id]
    if not agent then
        logger.error("No agent found for client %d", client_id)
        return
    end
    
    -- 转发消息到游戏服务
    local ok, response = pcall(skynet.call, agent, "lua", "forward_message", msg)
    if not ok then
        logger.error("Failed to forward message: %s", response)
        return
    end
    
    -- 再次检查客户端连接状态
    if not websocket.isconnected(client_id) then
        logger.error("Client %d disconnected during message processing", client_id)
        -- 清理连接
        handler.close(client_id)
        return
    end
    
    -- 发送响应给客户端
    CMD.send_message(client_id, response)
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