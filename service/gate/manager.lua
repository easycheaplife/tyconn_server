local skynet = require "skynet"
local logger = require "logger"

local CMD = {}

function CMD.start(conf)
    -- 启动WebSocket服务器
    local server = skynet.newservice("gate/server")
    local ok = skynet.call(server, "lua", "start", {
        port = conf.port,
        game_nodes = conf.game_nodes  -- 改为 game_nodes
    })
    return ok
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)