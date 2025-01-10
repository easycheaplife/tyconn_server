local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"

-- 消息处理模块
local handlers = {}

-- 命令处理模块
local CMD = {}

-- 打印所有类型的辅助函数
local function print_types()
    local result = {}
    local types = pb.types()
    for name in types do
        table.insert(result, string.format("%s (%s)", name, pb.type(name)))
    end
    return table.concat(result, "\n")
end

-- 打印所有枚举值的辅助函数
local function print_enums()
    local result = {}
    -- 获取所有类型
    local types = pb.types()
    for name in types do
        if pb.type(name) == "enum" then
            local values = {}
            local fields = pb.fields(name)
            for k, v in pairs(fields) do
                table.insert(values, string.format("%s=%d", k, v))
            end
            table.insert(result, string.format("%s: {%s}", name, table.concat(values, ", ")))
        end
    end
    return table.concat(result, "\n")
end

-- 添加打印用户信息的函数
local function print_user_stats()
    local user_model = require "game.models.user"
    local stats = user_model.get_stats()
    
    -- 获取当前时间
    local current_time = os.date("%Y-%m-%d %H:%M:%S")
    
    -- 打印统计信息
    logger.info("[%s] [INFO] User Statistics:", current_time)
    logger.info("[%s] [INFO] - Total Users: %d", current_time, stats.total_users)
    logger.info("[%s] [INFO] - Online Users: %d", current_time, stats.online_users)
    logger.info("[%s] [INFO] Recent Registered Users:", current_time)
    
    -- 打印最近注册用户信息
    for _, user in ipairs(stats.recent_users) do
        local register_time = os.date("%Y-%m-%d %H:%M:%S", user.register_time)
        logger.info("[%s] [INFO]   - ID: %d, Name: %s, Level: %d, Register Time: %s",
            current_time,
            user.user_id,
            user.username,
            user.level,
            register_time
        )
    end
end

-- 初始化消息处理器
local function init_handlers()
    -- 打印所有已加载的类型
    logger.debug("Available types:\n%s", print_types())
    
    -- 打印所有可用的枚举值
    logger.debug("Available enums:\n%s", print_enums())
    
    -- 获取消息ID
    local login_msg_id = pb.enum("common.MessageID", "C2S_LOGIN_REQUEST")
    local register_msg_id = pb.enum("common.MessageID", "C2S_REGISTER_REQUEST")
    
    if not login_msg_id then
        logger.error("Failed to get message id for C2S_LOGIN_REQUEST")
        return false
    end
    
    if not register_msg_id then
        logger.error("Failed to get message id for C2S_REGISTER_REQUEST")
        return false
    end
    
    -- 打印所有 MessageID 枚举值
    local message_ids = {
        NONE = pb.enum("common.MessageID", "NONE") or 0,
        C2S_LOGIN_REQUEST = pb.enum("common.MessageID", "C2S_LOGIN_REQUEST") or 0,
        S2C_LOGIN_RESPONSE = pb.enum("common.MessageID", "S2C_LOGIN_RESPONSE") or 0,
        C2S_REGISTER_REQUEST = pb.enum("common.MessageID", "C2S_REGISTER_REQUEST") or 0,
        S2C_REGISTER_RESPONSE = pb.enum("common.MessageID", "S2C_REGISTER_RESPONSE") or 0
    }
    
    for name, id in pairs(message_ids) do
        logger.debug("MessageID %s = %d", name, id)
    end
    
    -- 注册处理器
    handlers[login_msg_id] = require "game.handlers.login"
    handlers[register_msg_id] = require "game.handlers.register"
    
    return true
end

function CMD.client_message(source, client_id, msg)
    -- 解析消息类型
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return
    end
    
    if not base_request then
        logger.error("Failed to decode base request")
        return
    end
    
    -- 打印会话信息
    if base_request.session then
        logger.debug("Session info: messageId=%d, sequence=%d, timestamp=%d, version=%s",
            base_request.session.messageId or 0,
            base_request.session.sequence or 0,
            base_request.session.timestamp or 0,
            base_request.session.version or ""
        )
    else
        logger.error("No session in request")
    end
    
    -- 处理消息
    local msg_id = base_request.session and base_request.session.messageId or 0
    local handler = handlers[msg_id]
    if handler then
        local response = handler.handle(client_id, msg)
        if response then
            cluster.send("gate1", source, "client_message", response)
        end
    else
        logger.error("Unknown message id: %d", msg_id)
    end
end

function CMD.client_disconnect(_, client_id)
    local user_model = require "game.models.user"
    user_model.remove_user(client_id)
end

local function init_db()
    local user_model = require "game.models.user"
    if not user_model.init() then
        logger.error("Failed to initialize database")
        return false
    end
    return true
end

-- 服务入口
skynet.start(function()
    logger.info("Game server starting...")
    
    -- 初始化数据库
    if not init_db() then
        logger.error("Failed to initialize database")
        return
    end
    
    -- 加载协议文件
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return
    end
    logger.info("Proto files loaded")
    
    -- 初始化消息处理器
    if not init_handlers() then
        logger.error("Failed to initialize handlers")
        return
    end
    logger.info("Handlers initialized")
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
    
    -- 添加定时器，每30秒打印一次用户信息
    skynet.fork(function()
        while true do
            skynet.sleep(3000)  -- 30秒 (100 = 1秒)
            print_user_stats()
        end
    end)
    
    logger.info("Game server started")
end)