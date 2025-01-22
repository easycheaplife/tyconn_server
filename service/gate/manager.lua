local skynet = require "skynet"
local logger = require "logger"

local server
local CMD = {}

function CMD.start(conf)
    -- 确保环境变量已设置
    local node_name = skynet.getenv("node_name")
    local ws_host = skynet.getenv("websocket_host")
    local ws_port = skynet.getenv("websocket_port")
    
    if not node_name or not ws_host or not ws_port then
        logger.error("Missing required environment variables:")
        logger.error("  node_name = %s", node_name)
        logger.error("  websocket_host = %s", ws_host)
        logger.error("  websocket_port = %s", ws_port)
        return false
    end

    -- 启动网关服务器
    server = skynet.newservice("gate/server")
    local ok = skynet.call(server, "lua", "start", conf)
    if not ok then
        logger.error("Failed to start gate server")
        return false
    end
    
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", cmd)
        end
    end)
end)