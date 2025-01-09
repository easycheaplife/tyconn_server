local skynet = require "skynet"

local CMD = {}
local gateway_service

function CMD.start(conf)
    gateway_service = skynet.newservice("gate/server")
    skynet.call(gateway_service, "lua", "start", {
        port = conf.port,
        game = conf.game,
        game_node = conf.game_node
    })
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)