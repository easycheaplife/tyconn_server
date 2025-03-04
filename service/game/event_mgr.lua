local skynet = require "skynet"
local event_service = require "services.event_service"
local logger = require "logger"
local utils = require "utils"   

local CMD = {}

function CMD.trigger_event(event_name, event_data)
    logger.debug("Event triggered: %s", event_name)
    logger.debug("Event data: %s", utils.table_to_string(event_data))
    event_service.handle_event(event_name, event_data)
end

skynet.start(function()
    logger.info("Event manager started with address: %s", skynet.self())  -- 打印服务地址
    
    skynet.dispatch("lua", function(session, source, cmd, ...)
        logger.debug("Received command: %s from %s", cmd, skynet.address(source))  -- 打印命令来源
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command %s", cmd)
        end
    end)
end) 