local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"
local jwt = require "jwt"

-- 创建基础响应
local function create_base_response(session, error_code, error_msg, payload)
    return {
        session = {
            messageId = session.messageId,  -- 由具体的处理器设置正确的响应消息ID
            sequence = session.sequence,
            timestamp = os.time(),
            version = session.version
        },
        errorCode = error_code or 0,
        errorMsg = error_msg or "success",
        payload = payload
    }
end

-- 消息处理模块
local handlers = {}

-- 命令处理模块
local CMD = {}

-- 初始化消息处理器
local function init_handlers()
    -- 注册处理器
    handlers[pb.enum("common.MessageID", "C2G_AUTH_REQUEST")] = require "game.handlers.auth"
    handlers[pb.enum("common.MessageID", "C2G_GET_ROLE_REQUEST")] = require "game.handlers.get_role"
    handlers[pb.enum("common.MessageID", "C2G_CREATE_ROLE_REQUEST")] = require "game.handlers.create_role"
    handlers[pb.enum("common.MessageID", "C2S_HEARTBEAT")] = require "game.handlers.heartbeat"
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

-- 验证token并获取用户信息
local function verify_token_and_get_user(token)
    local jwt_secret = skynet.getenv("jwt_secret")
    if not jwt_secret then
        logger.error("Missing jwt_secret in environment")
        return false
    end
    
    -- 解析 token
    local ok, claims = pcall(jwt.decode, token, jwt_secret)
    if not ok then
        logger.error("Failed to decode token: %s", claims)
        logger.debug("Token details: %s", token)
        return false
    end
    
    -- 获取用户信息
    return {
        user_id = claims.user_id,
        username = claims.username
    }
end

-- 获取角色信息
function CMD.get_role(token)
    -- 验证token
    local user, err = verify_token_and_get_user(token)
    if not user then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = err
        }
    end
    
    -- 从数据库获取角色信息
    local ok, user_info = pcall(cluster.call, "db_proxy", "@db_proxy", "get_user", user.user_id)
    if not ok then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "获取角色信息失败"
        }
    end
    
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        has_role = user_info and user_info.name ~= "",
        user = user_info
    }
end

-- 创建角色
function CMD.create_role(token, name, gender, job)
    -- 验证token
    local user, err = verify_token_and_get_user(token)
    if not user then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = err
        }
    end
    
    -- 检查角色名是否已存在
    local ok, exists = pcall(cluster.call, "db_proxy", "@db_proxy", "check_name_exists", name)
    if not ok then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "系统错误"
        }
    end
    
    if exists then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_NAME_EXISTS"),
            message = "角色名已存在"
        }
    end
    
    -- 创建角色
    local ok, user_info = pcall(cluster.call, "db_proxy", "@db_proxy", "update_user", {
        user_id = user.user_id,
        name = name,
        gender = gender,
        job = job,
        level = 1,
        exp = 0,
        vip_level = 0,
        create_time = os.time(),
        login_time = os.time()
    })
    
    if not ok or not user_info then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "创建角色失败"
        }
    end
    
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "success",
        user = user_info
    }
end

-- 检查版本
local function check_version(version)
    if not version then
        return false
    end
    
    -- 检查版本格式
    if not string.match(version, "^%d+%.%d+%.%d+$") then
        return false
    end
    
    -- 检查最低版本要求
    if compare_version(version, skynet.getenv("version_min")) < 0 then
        return false
    end
    
    -- 如果强制更新，检查是否是最新版本
    if skynet.getenv("version_force_update") == "true" and 
       compare_version(version, skynet.getenv("version_latest")) < 0 then
        return false
    end
    
    return true
end

-- 服务入口
function CMD.start(conf)
    -- 保存配置
    jwt_secret = conf.jwt_secret
    
    -- 打印环境变量
    logger.debug("Environment variables:")
    logger.debug("  jwt_secret = %s", jwt_secret)

    -- 加载proto文件
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return false
    end
    
    return true
end

-- 注册消息处理函数
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