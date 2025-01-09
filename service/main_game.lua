local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    cluster.reload {
        game = "127.0.0.1:2002",
        gate = "127.0.0.1:2003",
    }
    
    local game = skynet.newservice("game")
    cluster.register("game", game)
    cluster.open "game"
end)