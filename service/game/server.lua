local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"

-- 消息处理模块
local handlers = {}

-- 命令处理模块
local CMD = {}

-- 初始化消息处理器
local function init_handlers()
    -- 注册处理器
    handlers[pb.enum("common.MessageID", "C2S_LOGIN_REQUEST")] = require "game.handlers.login"
    return true
end

-- 处理客户端消息
function CMD.client_message(source, client_id, msg, gate_node)
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok or not base_request then
        logger.error("Failed to decode base request: %s", base_request)
        return
    end
    
    -- 验证会话信息
    if not base_request.session then
        logger.error("No session in request")
        return
    end
    
    -- 打印会话信息
    logger.debug("Session info: messageId=%d, sequence=%d, timestamp=%d, version=%s",
        base_request.session.messageId or 0,
        base_request.session.sequence or 0,
        base_request.session.timestamp or 0,
        base_request.session.version or ""
    )
    
    -- 处理消息
    local msg_id = base_request.session.messageId
    local handler = handlers[msg_id]
    if handler then
        local response = handler.handle(client_id, msg)
        if response then
            cluster.send(gate_node, source, "client_message", response)
        end
    else
        logger.error("Unknown message id: %d", msg_id)
    end
end

-- 处理客户端断开连接
function CMD.client_disconnect(_, client_id)
    local user_model = require "game.models.user"
    user_model.remove_user(client_id)
end

-- 服务入口
skynet.start(function()
    logger.info("Game server starting...")
    
    -- 加载 proto 文件
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
    
    logger.info("Game server started")
end)