-- ws_agent.lua
-- WebSocket 代理服务
-- 负责处理单个客户端连接的消息收发
-- 作为 gate 和 game 服务之间的中间层

local skynet = require "skynet"
local cluster = require "skynet.cluster"

local gate, client_fd, game, game_node

local CMD = {}

function CMD.start(conf)
    client_fd = conf.fd
    game = conf.game
    game_node = conf.game_node
    gate = conf.gate
end

function CMD.message(msg)
    cluster.send(game_node, game, "client_message", skynet.self(), client_fd, msg)
end

function CMD.client_message(msg)
    skynet.send(gate, "lua", "send_message", client_fd, msg)
end

function CMD.disconnect()
    cluster.send(game_node, game, "client_disconnect", skynet.self(), client_fd)
    skynet.exit()
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end) 