local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"

local users = {}

-- 测试登录功能
local function test_login()
    local test_data = {
        account = "test",
        password = "123456",
        device_id = "test_device",
        platform = "web",
        version = "1.0.0"
    }
    
    local ok, bytes = pcall(pb.encode, "login.C2SLoginRequest", test_data)
    if not ok then
        logger.error("编码登录请求失败: %s", bytes)
        return
    end
    
    local ok, decoded = pcall(pb.decode, "login.C2SLoginRequest", bytes)
    if ok then
        logger.info("解码登录请求成功:")
        logger.info("账号: %s", decoded.account)
        logger.info("密码: %s", decoded.password)
        logger.info("设备: %s", decoded.device_id)
    end
end

-- 消息处理函数
local handlers = {
    login = function(client_id, msg)
        -- 解码登录请求
        local ok, request = pcall(pb.decode, "login.C2SLoginRequest", msg)
        if not ok then
            logger.error("解码登录请求失败: %s", request)
            return pb.encode("login.S2CLoginResponse", {
                code = pb.enum("login.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
                message = "无效的请求格式"
            })
        end
        
        -- 验证账号密码
        if request.account == "test" and request.password == "123456" then
            -- 创建用户信息
            local user_info = {
                user_id = 10001,            -- int64
                nickname = "测试账号",      -- string
                level = 1,                  -- int32
                exp = 0,                    -- int64
                vip_level = 0,              -- int32
                gold = 1000,                -- int64
                diamond = 100,              -- int64
                avatar = "default.png",     -- string
                register_time = os.time(),  -- int64
                last_login = os.time()      -- int64
            }
            
            logger.debug("user_info: %s", table.concat({
                string.format("user_id=%d", user_info.user_id),
                string.format("nickname=%s", user_info.nickname),
                string.format("level=%d", user_info.level)
            }, ", "))
            
            -- 创建登录响应
            local response = {
                code = pb.enum("login.ErrorCode", "ERROR_CODE_SUCCESS"),
                message = "登录成功",
                user_info = user_info,
                token = "dummy_token_" .. client_id
            }
            
            -- 记录用户信息
            users[client_id].user_info = user_info
            
            -- 编码并返回响应
            local ok, encoded = pcall(pb.encode, "login.S2CLoginResponse", response)
            if not ok then
                logger.error("编码登录响应失败: %s", encoded)
                return pb.encode("login.S2CLoginResponse", {
                    code = pb.enum("login.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
                    message = "系统错误"
                })
            end
            return encoded
        else
            -- 登录失败响应
            return pb.encode("login.S2CLoginResponse", {
                code = pb.enum("login.ErrorCode", "ERROR_CODE_WRONG_PASSWORD"),
                message = "账号或密码错误"
            })
        end
    end
}

local CMD = {}

function CMD.client_message(source, client_id, msg)
    if not users[client_id] then
        users[client_id] = {
            agent = source,
            node = "gate1"
        }
    end
    
    local cmd, params = string.match(msg, "([^|]+)|?(.*)")
    cmd = cmd or msg
    
    local handler = handlers[cmd]
    if handler then
        local response = handler(client_id, params)
        if response then
            cluster.send("gate1", source, "client_message", response)
        end
    end
end

function CMD.client_disconnect(_, client_id)
    users[client_id] = nil
end

skynet.start(function()
    logger.info("Game server starting...")
    
    -- 使用 protoloader 加载 proto 文件
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return
    end
    
    -- 运行测试
    test_login()
    
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
    
    logger.info("Game server started")
end)