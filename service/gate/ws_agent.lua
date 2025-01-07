local skynet = require "skynet"
local logger = require "logger"

local gate
local client_fd
local game

local CMD = {}

function CMD.start(conf)
    client_fd = conf.fd
    game = conf.game
    gate = conf.gate
    logger.info("Agent(%d) started for client fd=%d", skynet.self(), client_fd)
end

function CMD.disconnect()
    logger.info("Agent(%d) client disconnected, fd=%d", skynet.self(), client_fd)
    skynet.send(game, "lua", "client_disconnect", client_fd)
    skynet.exit()
end

function CMD.message(msg, msg_type)
    logger.debug("Agent(%d) received message from fd=%d: %s", skynet.self(), client_fd, msg)
    skynet.send(game, "lua", "client_message", client_fd, msg, msg_type)
end

function CMD.send_client(msg)
    logger.debug("Agent(%d) sending message to fd=%d: %s", skynet.self(), client_fd, msg)
    skynet.send(gate, "lua", "send_message", client_fd, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Agent(%d) unknown command: %s", skynet.self(), cmd)
        end
    end)
end) 