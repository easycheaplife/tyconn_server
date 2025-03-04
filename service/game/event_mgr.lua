local skynet = require "skynet"
local event_service = require "services.event_service"
local logger = require "logger"

local CMD = {}

function CMD.trigger_event(event_name, event_data)
    logger.info("Event triggered: %s with data: %s", 
        event_name, 
        logger.dump(event_data)  -- 打印完整的事件数据
    )
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