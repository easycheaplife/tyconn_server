local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"

local users = {}

local handlers = {
    hello = function(_, msg)
        return string.format("Hello %s!", msg)
    end,
    
    echo = function(_, msg)
        return msg
    end
}

local CMD = {}

function CMD.client_message(source, client_id, msg)
    if not users[client_id] then
        users[client_id] = {
            agent = source,
            node = "gate1"
        }
    end
    
    local cmd, params = string.match(msg, "([^|]+)|?(.*)")
    cmd = cmd or msg
    params = params or ""
    
    local handler = handlers[cmd]
    if handler then
        local response = handler(client_id, params)
        if response then
            cluster.send("gate1", source, "client_message", response)
        end
    else
        cluster.send("gate1", source, "client_message", msg)
    end
end

function CMD.client_disconnect(_, client_id)
    users[client_id] = nil
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)