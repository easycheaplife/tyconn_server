local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"
local jwt = require "jwt"
local cluster_util = require "cluster_util"

local clients = {}  -- client_id -> session info
local jwt_secret
local jwt_expire
local gate_nodes = {}  -- 网关节点信息
local gate_index = 0   -- 用于轮询

-- 发送错误响应
local function send_error_response(client_id, session, message, error_code)
    logger.debug("Sending error response: client=%d, message=%s, error_code=%s",
        client_id, message, tostring(error_code))
    
    local response = {
        session = session,
        errorCode = error_code or pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
        errorMsg = message
    }
    
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", response)
    if ok then
        logger.debug("Sending binary response, length: %d", #encoded)
        websocket.write(client_id, encoded, "binary")
    else
        logger.error("Failed to encode error response: %s", encoded)
    end
end

-- 发送登录响应
local function send_login_response(client_id, session, data)
    logger.debug("Sending login response: client=%d, gate=%s:%d",
        client_id, data.gate_addr, data.gate_port)
    
    local login_response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "登录成功",
        token = data.token,
        gate_addr = data.gate_addr,
        gate_port = data.gate_port
    }
    
    local ok, payload = pcall(pb.encode, "command.S2LLoginResponse", login_response)
    if not ok then
        logger.error("Failed to encode login response: %s", payload)
        send_error_response(client_id, session, "系统错误")
        return
    end
    
    local base_response = {
        session = session,
        errorCode = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        errorMsg = "",
        payload = payload
    }
    
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", base_response)
    if ok then
        logger.debug("Sending binary response, length: %d", #encoded)
        websocket.write(client_id, encoded, "binary")
    else
        logger.error("Failed to encode base response: %s", encoded)
    end
end

-- 选择网关
local function select_gate()
    -- 检查可用网关
    local available_gates = {}
    for name, info in pairs(gate_nodes) do
        if info.available then
            table.insert(available_gates, {
                name = name,
                host = info.host,
                port = info.port
            })
        end
    end
    
    if #available_gates == 0 then
        return nil
    end
    
    -- 简单轮询选择
    gate_index = (gate_index % #available_gates) + 1
    return available_gates[gate_index]
end

-- 生成JWT令牌
local function generate_token(user)
    local claims = {
        user_id = user.user_id,
        username = user.username,
        exp = os.time() + jwt_expire,
        iat = os.time(),
        iss = "tyconn_login"
    }
    return jwt.encode(claims, jwt_secret)
end

-- 比较版本号
local function compare_version(ver1, ver2)
    logger.debug("Comparing versions: %s vs %s", ver1, ver2)
    local v1 = {}
    local v2 = {}
    
    for num in ver1:gmatch("%d+") do
        table.insert(v1, tonumber(num))
    end
    
    for num in ver2:gmatch("%d+") do
        table.insert(v2, tonumber(num))
    end
    
    logger.debug("Parsed versions: v1=[%s], v2=[%s]", 
        table.concat(v1, "."), 
        table.concat(v2, ".")
    )
    
    for i = 1, 3 do
        -- 确保两个版本号都有完整的三段
        v1[i] = v1[i] or 0
        v2[i] = v2[i] or 0
        
        if v1[i] > v2[i] then 
            logger.debug("Version %s > %s at position %d (%d > %d)", 
                ver1, ver2, i, v1[i], v2[i])
            return 1 
        end
        if v1[i] < v2[i] then 
            logger.debug("Version %s < %s at position %d (%d < %d)", 
                ver1, ver2, i, v1[i], v2[i])
            return -1 
        end
    end
    
    logger.debug("Versions are equal: %s = %s", ver1, ver2)
    return 0
end

-- 检查版本号
local function check_version(version)
    logger.debug("Enter check_version function with version: %s", version)
    local min_version = skynet.getenv("version_min")
    local latest_version = skynet.getenv("version_latest")
    local force_update = skynet.getenv("version_force_update")

    logger.debug("Checking version: client=%s, min=%s, latest=%s, force=%s",
        version, min_version, latest_version, force_update)

    if not version then
        logger.warn("Client version is nil")
        return false
    end
    
    -- 检查版本格式
    if not string.match(version, "^%d+%.%d+%.%d+$") then
        logger.warn("Invalid version format: %s", version)
        return false
    end
    
    -- 检查环境变量是否正确设置
    if not min_version then
        logger.warn("Minimum version not set in environment")
        return false
    end
    
    -- 检查最低版本要求
    if min_version and compare_version(version, min_version) < 0 then
        logger.debug("Comparing version %s with minimum version %s", version, min_version)
        logger.warn("Version too old: client=%s, required=%s", version, min_version)
        return false
    end
    
    -- 检查强制更新设置
    if force_update then
        logger.debug("Force update setting: %s", force_update)
    end
    
    -- 如果强制更新，检查是否是最新版本
    if force_update == "true" and latest_version and
       compare_version(version, latest_version) < 0 then
        logger.warn("Force update required: client=%s, latest=%s", version, latest_version)
        return false
    end
    
    logger.debug("Version check passed: %s", version)
    return true
end

-- 初始化网关节点
local function init_gate_nodes()
    -- 使用 cluster_util 加载配置
    local env = cluster_util.load_cluster_config()
    
    -- 解析配置
    for name, addr in pairs(env) do
        if name:match("^gate%d+$") then
            local host, port = addr:match("([^:]+):(%d+)")
            gate_nodes[name] = {
                host = host,
                port = tonumber(port),
                available = true
            }
            logger.info("Found gate node: %s at %s:%d", name, host, port)
        end
    end
end

-- WebSocket处理函数
local ws_handler = {}

function ws_handler.connect(client_id)
    logger.debug("New client connected: %d", client_id)
    clients[client_id] = {
        connect_time = os.time()
    }
end

function ws_handler.message(client_id, msg, msg_type)
    logger.debug("Received message from client %d, type: %s, length: %d", 
        client_id, msg_type or "unknown", #msg)
    
    -- 创建默认会话信息，用于错误响应
    local default_session = {
        messageId = 0,
        sequence = 0,
        timestamp = os.time()
    }
    
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        send_error_response(client_id, default_session, 
            "无效的请求格式",
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAMS"))
        return
    end
    
    logger.debug("Decoded base request: messageId=%d, sequence=%d, timestamp=%d, version=%s",
        base_request.session.messageId or 0,
        base_request.session.sequence or 0,
        base_request.session.timestamp or 0,
        base_request.session.version or ""
    )
    
    -- 解码登录请求
    local ok, request = pcall(pb.decode, "command.C2LLoginRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode login request: %s", request)
        send_error_response(client_id, base_request.session,
            "无效的登录请求",
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAMS"))
        return
    end
    
    -- 检查必要的参数
    if not request.account or request.account == "" then
        logger.warn("Missing account in login request")
        send_error_response(client_id, base_request.session,
            "账号不能为空",
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_ACCOUNT"))
        return
    end
    
    if not request.password or request.password == "" then
        logger.warn("Missing password in login request")
        send_error_response(client_id, base_request.session,
            "密码不能为空",
            pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PASSWORD"))
        return
    end
    
    logger.debug("Login request: account=%s, platform=%s, version=%s",
        request.account,
        request.platform,
        request.version
    )
    logger.debug("Starting version check for version: %s", request.version)
    
    -- 打印请求的完整内容
    logger.debug("Full request content:")
    for k, v in pairs(request) do
        logger.debug("  %s = %s", k, tostring(v))
    end
    
    -- 验证版本号
    if not check_version(request.version) then
        logger.warn("Version check failed: client=%s, required=%s",
            request.version,
            skynet.getenv("version_min")
        )
        send_error_response(client_id, base_request.session, 
            "版本号不匹配", 
            pb.enum("common.ErrorCode", "ERROR_CODE_VERSION_NOT_MATCH")
        )
        return
    end
  
    logger.debug("Version check passed, proceeding to account verification")
    
    -- 验证用户
    logger.debug("Verifying account: %s", request.account)
    local ok, user = pcall(cluster.call, "db_proxy", "@db_proxy", "verify_account", 
        request.account, request.password)
    if not ok or not user then
        logger.warn("Account verification failed for: %s", request.account)
        send_error_response(client_id, base_request.session, "账号或密码错误")
        return
    end
    logger.info("Account verified successfully: %s (ID: %s)", 
        user.username, user.user_id)
    
    -- 生成token
    local token = generate_token(user)
    if not token then
        logger.error("Failed to generate token for user: %s", user.username)
        send_error_response(client_id, base_request.session, "系统错误")
        return
    end
    logger.debug("Generated token for user: %s", user.username)
    
    -- 同步token到数据库
    logger.debug("Syncing token for user: %s", user.username)
    local ok = pcall(cluster.call, "db_proxy", "@db_proxy", "sync_token", {
        token = token,
        user_id = user.user_id,
        username = user.username,
        expire_time = os.time() + jwt_expire,
        device_id = request.device_id,
        platform = request.platform
    })
    
    if not ok then
        logger.error("Failed to sync token for user: %s", user.username)
        send_error_response(client_id, base_request.session, "系统错误")
        return
    end
    logger.debug("Token synced for user: %s", user.username)
    
    -- 选择网关
    logger.debug("Selecting gate for user: %s", user.username)
    local gate = select_gate()
    if not gate then
        logger.error("No available gate found for user: %s", user.username)
        send_error_response(client_id, base_request.session, "没有可用的网关")
        return
    end
    logger.info("Selected gate %s for user %s", gate.name, user.username)
    
    -- 发送成功响应
    logger.debug("Sending login response to user: %s", user.username)
    send_login_response(client_id, base_request.session, {
        token = token,
        gate_addr = gate.host,
        gate_port = gate.port
    })
    logger.info("Login successful: user=%s, gate=%s:%d", 
        user.username, gate.host, gate.port)
end

function ws_handler.close(client_id)
    logger.debug("Client %d disconnected", client_id)
    clients[client_id] = nil
end

-- 命令处理模块
local CMD = {}

function CMD.start(conf)
    -- 保存配置
    jwt_secret = conf.jwt_secret
    jwt_expire = conf.jwt_expire
    
    -- 打印环境变量
    logger.debug("Environment variables:")
    logger.debug("  jwt_secret = %s", jwt_secret)
    logger.debug("  jwt_expire = %s", jwt_expire)
    logger.debug("  version_min = %s", skynet.getenv("version_min"))
    logger.debug("  version_latest = %s", skynet.getenv("version_latest"))
    logger.debug("  version_force_update = %s", skynet.getenv("version_force_update"))
    
    -- 加载proto文件
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return false
    end
    
    -- 初始化网关节点
    init_gate_nodes()
    
    -- 启动WebSocket服务器
    local port = conf.port
    local id = socket.listen("0.0.0.0", port)
    socket.start(id, function(fd, addr)
        logger.debug("New connection from %s", addr)
        websocket.accept(fd, ws_handler)
    end)
    
    logger.info("Login server started on port %d", port)
    return true
end

skynet.start(function()
    logger.info("Login server starting...")
    
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end) 