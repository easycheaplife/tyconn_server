local skynet = require "skynet"
local logger = require "logger"
local log = logger.log

local gate
local client_fd
local game

local CMD = {}

function CMD.start(conf)
    client_fd = conf.fd
    game = conf.game
    gate = conf.gate
end

function CMD.disconnect()
    skynet.send(game, "lua", "client_disconnect", client_fd)
    skynet.exit()
end

function CMD.message(msg, msg_type)
    skynet.send(game, "lua", "client_message", client_fd, msg, msg_type)
end

function CMD.send_client(msg)
    skynet.send(gate, "lua", "send_message", client_fd, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end) 