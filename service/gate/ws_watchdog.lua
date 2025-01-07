local skynet = require "skynet"
local logger = require "logger"
local log = logger.log

local gate

local CMD = {}

function CMD.start(conf)
    gate = skynet.newservice("ws_gate")
    skynet.call(gate, "lua", "start", {
        port = conf.port,
        game = conf.game,
        watchdog = skynet.self()
    })
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end) 