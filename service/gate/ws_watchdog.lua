local skynet = require "skynet"
local logger = require "logger"  -- 引入日志模块
local log = logger.log          -- 简化调用

local gate  -- ws_gate service handle

local CMD = {}

function CMD.start(conf)
    -- 创建并启动 ws_gate
    gate = skynet.newservice("ws_gate")
    if not gate then
        log("Failed to create gate service")
        return false
    end
    
    log("Watchdog(%d) created gate service(%d)", skynet.self(), gate)
    
    -- 启动 gate 服务
    local ok = skynet.call(gate, "lua", "start", {
        port = conf.port,
        game = conf.game,
        watchdog = skynet.self()
    })
    
    if not ok then
        log("Failed to start gate service")
        return false
    end
    
    -- 开始监控
    skynet.fork(function()
        while true do
            if gate then
                -- 检查 gate 服务状态
                local status = skynet.call(gate, "lua", "status")
                log("Gate status: connections=%d", status.connection_count)
            end
            skynet.sleep(1000)  -- 每 10 秒检查一次
        end
    end)
    
    return true
end

function CMD.gate_error(error_type, ...)
    log("Watchdog(%d) received gate error: %s", skynet.self(), error_type)
    
    -- 处理不同类型的错误
    if error_type == "listen_failed" then
        -- 端口监听失败
        local port = ...
        log("Gate failed to listen on port %d", port)
    elseif error_type == "client_close" then
        -- 客户端正常断开
        local fd, code, reason = ...
        log("Client %d closed connection, code: %s, reason: %s", 
            fd, tostring(code), tostring(reason))
    elseif error_type == "ws_error" then
        -- WebSocket 错误
        local fd = ...
        log("WebSocket error on connection %d", fd)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
    
    log("Watchdog(%d) started", skynet.self())
end) 