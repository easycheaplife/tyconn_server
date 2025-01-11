local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    cluster.reload {
        game1 = "127.0.0.1:2002",
        gate1 = "127.0.0.1:2003",
    }
    
    local game_service_proxy = cluster.proxy("game1", "game1")
    local gateway_manager = skynet.newservice("gate/manager")
    local port = tonumber(skynet.getenv("websocket_port")) or 8008
    
    local ok = skynet.call(gateway_manager, "lua", "start", {
        port = port,
        game = game_service_proxy,
        game_node = "game1"
    })
    
    cluster.open "gate1"
end)