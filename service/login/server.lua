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
local gate_timeout = 15  -- 网关超时时间(秒)

-- 发送错误响应
local function send_error_response(client_id, session, message, error_code)
    local response = {
        session = session,
        errorCode = error_code or pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
        errorMsg = message
    }
    
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", response)
    if ok then
        websocket.write(client_id, encoded, "binary")
    else
        logger.error("Failed to encode error response: %s", encoded)
    end
end

-- 发送登录响应
local function send_login_response(client_id, session, data)
    local login_response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "登录成功",
        token = data.token,
        ws_addr = data.ws_addr,
        ws_port = data.ws_port
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
        websocket.write(client_id, encoded, "binary")
    else
        logger.error("Failed to encode base response: %s", encoded)
    end
end

-- 选择网关
local function select_gate()
    -- 检查可用网关
    local available_gates = {}
    logger.debug("Checking available gates:")
    for name, info in pairs(gate_nodes) do
        logger.debug("  Gate %s: available=%s, host=%s, port=%d", 
            name, 
            tostring(info.available),
            info.host,
            info.port
        )
        if info.available then
            table.insert(available_gates, {
                name = name,
                host = info.host,
                port = info.port
            })
        end
    end
    
    if #available_gates == 0 then
        logger.error("No available gates found")
        return nil
    end
    
    logger.debug("Found %d available gates", #available_gates)
    
    -- 简单轮询选择
    gate_index = (gate_index % #available_gates) + 1
    local selected = available_gates[gate_index]
    logger.debug("Selected gate %s at %s:%d", 
        selected.name, selected.host, selected.port)
    return available_gates[gate_index]
end

-- 生成JWT令牌
local function generate_token(user)
    logger.debug("Generating token for user: %s with secret: %s", 
        user.username, jwt_secret)
    
    local claims = {
        user_id = user.user_id,
        username = user.username,
        exp = os.time() + jwt_expire,
        iat = os.time(),
        iss = "tyconn_login"
    }
    
    logger.debug("Token claims: %s", table.concat({
        string.format("user_id=%d", claims.user_id),
        string.format("username=%s", claims.username),
        string.format("exp=%d", claims.exp),
        string.format("iat=%d", claims.iat),
        string.format("iss=%s", claims.iss)
    }, ", "))
    
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

-- WebSocket处理函数
local ws_handler = {}

function ws_handler.connect(client_id)
    clients[client_id] = {
        connect_time = os.time()
    }
end

function ws_handler.message(client_id, msg, msg_type)
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
        send_error_response(client_id, default_session, "无效的请求格式")
        return
    end
    
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
    logger.info("Account verified successfully: %s", user.username)
    
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
        ws_addr = gate.host,
        ws_port = gate.port
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

-- 清理超时的网关
local function cleanup_gates()
    local now = os.time()
    local removed = false
    
    for name, info in pairs(gate_nodes) do
        if info.last_sync and (now - info.last_sync > gate_timeout) then
            logger.warn("Gate %s timeout, removing from available list", name)
            gate_nodes[name] = nil
            removed = true
        end
    end
    
    if removed then
        -- 重置轮询索引
        gate_index = 0
    end
end

-- 更新网关状态
function CMD.update_gate_status(status_data)
    
    if not status_data then
        logger.error("Received nil status data")
        return false
    end
    
    local ok, status = pcall(pb.decode, "internal.ServiceStatus", status_data)
    if not ok then
        logger.error("Failed to decode gate status: %s, data length: %d", 
            status, #status_data)
        -- 尝试解码为其他类型
        local ok2, msg = pcall(pb.decode, "command.S2LLoginResponse", status_data)
        if ok2 then
            logger.error("Data appears to be S2LLoginResponse instead of ServiceStatus")
        end
        return false
    end
    
    if not status.node_name or status.node_name == "" then
        logger.error("Invalid gate status update: missing node_name, service_type=%s", 
            status.service_type or "unknown")
        -- 打印完整的解码结果
        logger.error("Decoded status: %s", 
            table.concat({
                string.format("node_name=%s", status.node_name or "nil"),
                string.format("service_type=%s", status.service_type or "nil"),
                string.format("host=%s", status.host or "nil"),
                string.format("port=%s", status.port or "nil"),
                string.format("client_count=%s", status.client_count or "nil"),
                string.format("timestamp=%s", status.timestamp or "nil")
            }, ", ")
        )
        return false
    end
    
    gate_nodes[status.node_name] = {
        host = status.host,
        port = status.port,
        client_count = status.client_count,
        last_sync = status.timestamp,
        available = true
    }
    
    return true
end

-- 启动定时清理
skynet.fork(function()
    while true do
        cleanup_gates()
        skynet.sleep(100)  -- 每秒检查一次
    end
end)

skynet.start(function()
    logger.info("Login server starting...")
    
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end) 