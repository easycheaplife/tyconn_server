local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    cluster.reload {
        game1 = "127.0.0.1:2002",
        gate1 = "127.0.0.1:2003",
    }
    
    local game_service_handle = skynet.newservice("game/server")
    cluster.register("game1", game_service_handle)
    cluster.open "game1"
end)