local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    cluster.reload {
        game = "127.0.0.1:2002",
        gate = "127.0.0.1:2003",
    }
    
    local game = cluster.proxy("game", "game")
    local watchdog = skynet.newservice("ws_watchdog")
    local port = tonumber(skynet.getenv("websocket_port")) or 8891
    
    local ok = skynet.call(watchdog, "lua", "start", {
        port = port,
        game = game,
        game_node = "game"
    })
    
    cluster.open "gate"
end)