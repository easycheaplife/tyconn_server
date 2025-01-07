local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"  -- 引入日志模块
local log = logger.log          -- 简化调用

local connection = {}  -- fd -> agent
local watchdog        -- watchdog service
local game_service    -- game service

-- WebSocket 处理函数
local handler = {}

function handler.connect(fd)
    log("Gate(%d) new client connect, fd=%d", skynet.self(), fd)
    local agent = skynet.newservice("ws_agent")
    
    log("Gate(%d) created agent(%d) for client fd=%d", skynet.self(), agent, fd)
    
    skynet.call(agent, "lua", "start", { 
        fd = fd,
        game = game_service
    })
    connection[fd] = agent
end

function handler.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    log("Gate(%d) handshake from %s, url: %s", skynet.self(), addr, url)
    log("Gate(%d) handshake headers for fd=%d:", skynet.self(), fd)
    log("----------------------------------------")
    for k,v in pairs(header) do
        log("| %-30s | %s", k, v)  -- 左对齐30字符宽度
    end
    log("----------------------------------------")
end

function handler.message(fd, msg, msg_type)
    local agent = connection[fd]
    if agent then
        log("Gate(%d) forward message from client fd=%d to agent(%d), type=%s, msg=%s", 
            skynet.self(), fd, agent, msg_type, tostring(msg))
        skynet.send(agent, "lua", "message", msg, msg_type)
    else
        log("Gate(%d) no agent for fd=%d, message dropped: %s", 
            skynet.self(), fd, tostring(msg))
        -- 通知 watchdog 异常情况
        skynet.send(watchdog, "lua", "gate_error", "no_agent", fd)
    end
end

function handler.close(fd, code, reason)
    local agent = connection[fd]
    if agent then
        log("Gate(%d) client fd=%d closed connection, notify agent(%d), code=%s, reason=%s", 
            skynet.self(), fd, agent, tostring(code), tostring(reason))
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    else
        log("Gate(%d) client fd=%d closed connection but no agent found, code=%s, reason=%s", 
            skynet.self(), fd, tostring(code), tostring(reason))
    end
    -- 通知 watchdog 连接关闭
    skynet.send(watchdog, "lua", "gate_error", "client_close", fd, code, reason)
end

function handler.error(fd)
    local agent = connection[fd]
    if agent then
        log("Gate(%d) WebSocket error on fd=%d, notify agent(%d)", 
            skynet.self(), fd, agent)
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    else
        log("Gate(%d) WebSocket error on fd=%d but no agent found", 
            skynet.self(), fd)
    end
    -- 通知 watchdog 错误发生
    skynet.send(watchdog, "lua", "gate_error", "ws_error", fd)
end

local CMD = {}

function CMD.start(conf)
    watchdog = assert(conf.watchdog)
    game_service = assert(conf.game)
    local port = assert(conf.port)
    local protocol = conf.protocol or "ws"
    
    log("Gate(%d) starting on port %d", skynet.self(), port)
    
    local id = socket.listen("0.0.0.0", port)
    if not id then
        log("Gate(%d) failed to listen on port %d", skynet.self(), port)
        skynet.send(watchdog, "lua", "gate_error", "listen_failed", port)
        return false
    end
    
    socket.start(id, function(fd, addr)
        log("Gate(%d) new connection from %s, fd=%d", skynet.self(), addr, fd)
        websocket.accept(fd, handler, protocol, addr)
    end)
    
    log("Gate(%d) successfully started on port %d", skynet.self(), port)
    return true
end

-- 供 watchdog 查询状态
function CMD.status()
    local count = 0
    for _ in pairs(connection) do 
        count = count + 1 
    end
    return {
        connection_count = count,
    }
end

skynet.start(function()
    log("Gate(%d) service starting", skynet.self())
    
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