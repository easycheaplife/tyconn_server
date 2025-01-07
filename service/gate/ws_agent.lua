local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"  -- 引入日志模块
local log = logger.log          -- 简化调用

-- Add comments to clarify the architecture
-- This is a WebSocket agent that handles individual client connections
-- It replaces the traditional gate agent for WebSocket protocol support

local WATCHDOG
local client_fd
local game     -- game service handle

-- WebSocket 帧构建函数
local function build_websocket_frame(data, opcode)
    log("Agent(%d) building WebSocket frame, data length=%d, opcode=%s", 
        skynet.self(), #data, opcode)
        
    local payload_len = #data
    local header = {}
    
    -- 第一个字节: FIN + RSV + OPCODE
    -- FIN = 1, RSV1-3 = 0
    local first_byte = 0x80  -- 10000000
    if opcode == "text" then
        first_byte = 0x81  -- 10000001 for text
    elseif opcode == "binary" then
        first_byte = 0x82  -- 10000010 for binary
    end
    table.insert(header, string.char(first_byte))
    
    -- 第二个字节开始: MASK + PAYLOAD LEN
    -- MASK = 0 (服务器发送不需要掩码)
    if payload_len < 126 then
        table.insert(header, string.char(payload_len))
    elseif payload_len < 0xFFFF then
        table.insert(header, string.char(126))
        -- 拆分 16 位长度为两个字节
        local high = math.floor(payload_len / 256)
        local low = payload_len % 256
        table.insert(header, string.char(high))
        table.insert(header, string.char(low))
    else
        table.insert(header, string.char(127))
        -- 拆分 64 位长度为 8 个字节
        local len = payload_len
        local bytes = {}
        for i = 1, 8 do
            table.insert(bytes, 1, string.char(len % 256))
            len = math.floor(len / 256)
        end
        for _, b in ipairs(bytes) do
            table.insert(header, b)
        end
    end
    
    log("Agent(%d) WebSocket frame built, header length=%d", 
        skynet.self(), #header)
        
    -- 拼接头部和数据
    return table.concat(header) .. data
end

local CMD = {}
local CLIENT = {}

function CMD.start(conf)
    log("Agent(%d) starting with config: fd=%d, game=%d", 
        skynet.self(), conf.fd, conf.game)
        
    local fd = conf.fd
    client_fd = fd
    
    -- 直接使用传入的游戏服务
    game = assert(conf.game, "game service not found")
    log("Agent(%d) initialized with game service(%d)", skynet.self(), game)
    
    -- 通知 watchdog 准备就绪
    log("Agent(%d) notifying watchdog ready for fd=%d", skynet.self(), fd)
    skynet.call(WATCHDOG, "lua", "forward", fd)
    
    log("Agent(%d) started successfully", skynet.self())
end

function CMD.disconnect()
    log("Agent(%d) handling disconnect for fd=%d", skynet.self(), client_fd)
    
    -- 通知游戏服务客户端断开
    if game then
        log("Agent(%d) notifying game(%d) about client disconnect, fd=%d", 
            skynet.self(), game, client_fd)
        skynet.send(game, "lua", "client_disconnect", client_fd)
    end
    
    log("Agent(%d) exiting", skynet.self())
    skynet.exit()
end

function CMD.message(msg, msg_type)
    log("Agent(%d) received message from fd=%d, type=%s, content=%s", 
        skynet.self(), client_fd, msg_type, tostring(msg))
    
    -- 转发消息到游戏服务
    if game then
        log("Agent(%d) forwarding message to game(%d), fd=%d, type=%s", 
            skynet.self(), game, client_fd, msg_type)
        skynet.send(game, "lua", "client_message", client_fd, msg, msg_type)
    else
        log("Agent(%d) no game service available, message dropped", skynet.self())
    end
end

-- 发送消息给客户端
function CMD.send_client(msg)
    log("Agent(%d) sending message to client fd=%d, content=%s", 
        skynet.self(), client_fd, tostring(msg))
    
    -- 构建并发送 WebSocket 帧
    local frame = build_websocket_frame(msg, "text")
    
    log("Agent(%d) writing WebSocket frame to socket fd=%d, frame length=%d", 
        skynet.self(), client_fd, #frame)
    socket.write(client_fd, frame)
end

skynet.start(function()
    log("Agent(%d) service starting", skynet.self())
    
    WATCHDOG = skynet.self()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            log("Agent(%d) handling command: %s from source=%d", 
                skynet.self(), cmd, source)
            skynet.ret(skynet.pack(f(...)))
        else
            log("Agent(%d) received unknown command: %s from source=%d", 
                skynet.self(), cmd, source)
            skynet.ret(skynet.pack({"Unknown command"}))
        end
    end)
    
    log("Agent(%d) service started", skynet.self())
end) 