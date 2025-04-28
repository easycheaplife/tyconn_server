local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local logger = require "logger"
local protoloader = require "protoloader"
local ws_server = require "login.network.ws_server"
local login_mgr = require "login.login_mgr"
local gate_mgr = require "login.gate_mgr"
local balancer_service = require "balancer_service"

local CMD = {}

-- 启动服务
function CMD.start(conf)
    -- 验证配置
    if not conf.port then
        logger.error("Missing port in configuration")
        return false
    end
    
    if not conf.jwt_secret then
        logger.error("Missing jwt_secret in configuration")
        return false
    end
    
    -- 从环境变量获取版本配置
    conf.version_min = skynet.getenv("version_min")
    conf.version_latest = skynet.getenv("version_latest")
    conf.version_force_update = skynet.getenv("version_force_update")
    
    -- 初始化各个管理器
    local ok = login_mgr.init(conf)
    if not ok then
        logger.error("Failed to initialize login manager")
        return false
    end
    logger.info("Login manager initialized")
    
    ok = gate_mgr.init()
    if not ok then
        logger.error("Failed to initialize gate manager")
        return false
    end
    logger.info("Gate manager initialized")
    
    -- 加载proto文件
    ok = protoloader.load_directory("./proto")
    if not ok then
        logger.error("Failed to load proto files")
        return false
    end
    logger.info("Proto files loaded")
    
    -- 初始化service_balancer
    if not balancer_service.init("db_proxy", skynet.getenv("node_name")) then
        logger.error("Failed to initialize db_proxy balancer")
        return false
    end
    logger.info("DB proxy balancer initialized")
    
    -- 启动WebSocket服务器
    local id = socket.listen("0.0.0.0", conf.port)
    socket.start(id, function(fd, addr)
        logger.debug("New connection from %s", addr)
        websocket.accept(fd, ws_server, nil, "binary")
    end)
    
    logger.info("Login server started on port %d", conf.port)
    return true
end

-- 更新网关状态
function CMD.update_gate_status(status_data)
    return gate_mgr.update_status(status_data)
end

-- 服务入口
skynet.start(function()
    logger.info("Login server starting...")
    
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
end) 