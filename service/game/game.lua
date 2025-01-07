local skynet = require "skynet"
local logger = require "logger"

local users = {}  -- fd -> {agent = agent}
local handlers = {
    hello = function(fd, msg)
        logger.debug("Game(%d) handling hello command from fd=%d: %s", skynet.self(), fd, msg)
        return string.format("Hello %s!", msg)
    end,
    
    echo = function(fd, msg)
        logger.debug("Game(%d) handling echo command from fd=%d: %s", skynet.self(), fd, msg)
        return msg
    end
}

local CMD = {}

function CMD.client_message(source, fd, msg, msg_type)
    if not users[fd] then
        users[fd] = {agent = source}
        logger.info("Game(%d) new client connected from agent(%d), fd=%d", 
            skynet.self(), source, fd)
    end
    
    if msg_type == "text" then
        local cmd, params = string.match(msg, "([^|]+)|?(.*)")
        logger.debug("Game(%d) received command from fd=%d: %s, params: %s", 
            skynet.self(), fd, cmd, params)
        
        local handler = handlers[cmd]
        if handler then
            local response = handler(fd, params)
            if response then
                logger.debug("Game(%d) sending response to fd=%d: %s", 
                    skynet.self(), fd, response)
                skynet.send(source, "lua", "send_client", response)
            end
        else
            logger.error("Game(%d) unknown command from fd=%d: %s", 
                skynet.self(), fd, cmd)
        end
    end
end

function CMD.client_disconnect(_, fd)
    if users[fd] then
        logger.info("Game(%d) client disconnected, fd=%d", skynet.self(), fd)
        users[fd] = nil
    end
end

skynet.start(function()
    logger.info("Game(%d) service starting", skynet.self())
    
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(source, ...)))
        else
            logger.error("Game(%d) unknown command: %s", skynet.self(), cmd)
        end
    end)
    
    logger.info("Game(%d) service started", skynet.self())
end) 