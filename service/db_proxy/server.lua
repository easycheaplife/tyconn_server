local skynet = require "skynet"
local logger = require "logger"
local user_model = require "db_proxy.models.user"
local token_model = require "db_proxy.models.token"
local sql = require "db_proxy.sql.user"
local db_util = require "db_proxy.utils.db_util"

local CMD = {}

-- 初始化数据库连接
local function init_db()
    if not db_util.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    
    if not sql.init() then
        logger.error("Failed to initialize database tables")
        return false
    end
    
    return true
end

-- 用户相关操作
function CMD.create_user(user)
    return user_model.create_user(user)
end

function CMD.get_user(account)
    return user_model.get_user(account)
end

function CMD.update_user(user)
    return user_model.update_user(user)
end

function CMD.get_user_by_username(username)
    return user_model.get_user_by_username(username)
end

function CMD.get_user_by_id(user_id)
    return user_model.get_user_by_id(user_id)
end

function CMD.get_total_users()
    return user_model.get_total_users()
end

function CMD.get_recent_users()
    return user_model.get_recent_users()
end

function CMD.get_online_users()
    return user_model.get_online_users()
end

-- Token相关操作
function CMD.sync_jwt(token_info)
    logger.debug("Received sync_jwt request - Account: %s, Token length: %d", 
        token_info.account, #(token_info.token or ""))
    
    if not token_info or not token_info.account or not token_info.token then
        logger.error("Invalid token_info: %s", require("utils").table_to_string(token_info))
        return false, "Invalid token info"
    end
    
    return token_model.sync_token(token_info)
end

function CMD.verify_jwt(account, token)
    return token_model.verify_token(account, token)
end

-- 服务入口
skynet.start(function()
    logger.info("DB proxy server starting...")
    
    if not init_db() then
        logger.error("Failed to initialize database")
        skynet.exit()
        return
    end
    
    -- 启动定时清理过期token的任务
    skynet.fork(function()
        while true do
            token_model.clean_expired_tokens()
            skynet.sleep(3600 * 100)  -- 每小时清理一次
        end
    end)
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", cmd)
            if session > 0 then
                skynet.ret(skynet.pack(false))
            end
        end
    end)
    
    logger.info("DB proxy server started")
end) 