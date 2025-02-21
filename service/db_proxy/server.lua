local skynet = require "skynet"
local logger = require "logger"
local init = require "db_proxy.init"
local token_model = require "db_proxy.models.token"
local CMD = require "db_proxy.commands"

-- 服务入口
skynet.start(function()
    logger.info("DB proxy server starting...")
    
    -- 初始化
    if not init.init() then
        logger.error("Failed to initialize db_proxy")
        skynet.exit()
        return
    end
    
    -- 启动定时清理过期token的任务
    skynet.fork(function()
        while true do
            skynet.sleep(100)  -- 等待1秒再开始清理
            token_model.clean_expired_tokens()
            skynet.sleep(3600 * 100)  -- 直接使用3600秒(1小时)作为清理间隔
        end
    end)
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))  -- 不需要再包装 wrap_call，因为已经在 commands 中处理
        else
            logger.error("Unknown command: %s", cmd)
            if session > 0 then
                skynet.ret(skynet.pack(false, "Unknown command"))
            end
        end
    end)
    
    logger.info("DB proxy server started")
end) 