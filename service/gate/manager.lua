local skynet = require "skynet"
local logger = require "logger"

local CMD = {}
local gateway_service

function CMD.start(conf)
    gateway_service = skynet.newservice("gate/server")
    skynet.call(gateway_service, "lua", "start", {
        port = conf.port,
        game_services = conf.game_services
    })
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", cmd)
        end
    end)
end)