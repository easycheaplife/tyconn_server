local skynet = require "skynet"
local logger = require "logger"
local user_model = require "db_proxy.models.user"
local token_model = require "db_proxy.models.token"
local sql = require "db_proxy.sql.init"
local db_util = require "db_proxy.utils.db_util"
local card = require "db_proxy.models.card"
local item = require "db_proxy.models.item"

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

-- 包装错误处理
local function wrap_call(func, ...)
    local ok, result, err = pcall(func, ...)
    if not ok then
        logger.error("Call failed: %s", result)
        return false, "Internal error"
    end
    return result, err
end

-- 用户相关操作
function CMD.create_user(user)
    return wrap_call(user_model.create_user, user)
end

function CMD.get_user(account)
    return wrap_call(user_model.get_user, account)
end

function CMD.update_user(user)
    return wrap_call(user_model.update_user, user)
end

function CMD.get_user_by_username(username)
    return wrap_call(user_model.get_user_by_username, username)
end

function CMD.get_user_by_id(user_id)
    return wrap_call(user_model.get_user_by_id, user_id)
end

function CMD.get_total_users()
    return wrap_call(user_model.get_total_users)
end

function CMD.get_recent_users()
    return wrap_call(user_model.get_recent_users)
end

function CMD.get_online_users()
    return wrap_call(user_model.get_online_users)
end

-- Token相关操作
function CMD.sync_jwt(token_info)
    return wrap_call(token_model.sync_token, token_info)
end

function CMD.verify_jwt(account, token)
    return wrap_call(token_model.verify_token, account, token)
end

function CMD.renew_jwt(account, token, expire_time)
    return wrap_call(token_model.renew_token, account, token, expire_time)
end

-- 卡牌相关命令
function CMD.create_card(card)
    return wrap_call(card.create_card, card)
end

function CMD.batch_create_cards(cards)
    return card.batch_create_cards(cards)
end

function CMD.get_user_cards(user_id)
    return card.get_user_cards(user_id)
end

function CMD.update_card(card_info)
    return card.update_card(card_info)
end

-- 物品相关命令
function CMD.get_user_items(user_id)
    return item.get_user_items(user_id)
end

function CMD.update_user_items(user_id, items)
    return item.update_user_items(user_id, items)
end

function CMD.log_item_change(log)
    return item.log_item_change(log)
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
            skynet.sleep(100)  -- 等待1秒再开始清理
            token_model.clean_expired_tokens()
            skynet.sleep(3600 * 100)  -- 直接使用3600秒(1小时)作为清理间隔
        end
    end)
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(wrap_call(f, ...)))
        else
            logger.error("Unknown command: %s", cmd)
            if session > 0 then
                skynet.ret(skynet.pack(false, "Unknown command"))
            end
        end
    end)
    
    logger.info("DB proxy server started")
end) 