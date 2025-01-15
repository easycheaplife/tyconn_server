local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

local gateway_service
local client_id
local game_node_name
local gateway_node = skynet.getenv("node_name")

local CMD = {}

function CMD.start(conf)
    client_id = conf.client_id
    game_node_name = conf.game_node
    gateway_service = conf.gateway
end

function CMD.message(msg)
    cluster.send(game_node_name, "@" .. game_node_name, "client_message", 
        skynet.self(), client_id, msg, gateway_node)
end

function CMD.client_message(msg)
    skynet.send(gateway_service, "lua", "send_message", client_id, msg)
end

function CMD.disconnect()
    cluster.send(game_node_name, "@" .. game_node_name, "client_disconnect", 
        skynet.self(), client_id)
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