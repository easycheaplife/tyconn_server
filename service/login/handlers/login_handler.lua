local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local login_mgr = require "login.login_mgr"
local gate_mgr = require "login.gate_mgr"
local cluster = require "skynet.cluster"

local M = {}

-- 处理登录请求
function M.handle(client_id, base_request)
    local messageId = pb.enum("common.MessageID", "L2C_LOGIN_RESPONSE")
    base_request.session.timestamp = os.time()
    -- 解码登录请求
    local ok, request = pcall(pb.decode, "command.C2LLoginRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode login request: %s", request)
            return {
                code = pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM"),
                message = "invalid param",
            }
    end

    -- 检查必要的参数
    if not request.account or request.account == "" then
        logger.warn("Missing account in login request")
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_ACCOUNT"),
            message = "account is empty",
        }
    end

    -- 验证版本号
    if not login_mgr.check_version(request.version) then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_VERSION_NOT_MATCH"),
            message = "version not match",
        }
    end

    -- 验证账号密码
    local user_info = login_mgr.verify_account(request.account, request.password)
    if not user_info then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_ACCOUNT"),
            message = "account not exist",
        }
    end


    -- 生成token
    local token = login_mgr.generate_token(user_info)
    if not token then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "system error",
        }
    end

    -- 保存token到数据库
    logger.info("Saving token to database - Account: %s", user_info.account)
    local ok, err = pcall(cluster.call, "db_proxy", "@db_proxy", "sync_jwt", {
        account = user_info.account,
        token = token,
        device_id = request.device_id,
        platform = request.platform,
        expire_time = os.time() + login_mgr.get_token_expire(),
        create_time = os.time()
    })
    if not ok then
        logger.error("Failed to save token for account %s: %s", user_info.account, tostring(err))
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_SYSTEM_ERROR"),
            message = "system error",
        }
    end
    logger.info("Token saved successfully for account: %s", user_info.account)

    -- 选择网关
    local gate = gate_mgr.select_server()
    if not gate then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_GATE_NOT_AVAILABLE"),
            message = "gate not available",
        }
    end

    -- 获取网关地址
    local gate_addr = gate_mgr.get_addr(gate)
    if not gate_addr then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_GATE_NOT_AVAILABLE"),
            message = "gate not available",
        }
    end


    -- 返回成功响应
    logger.info("Login successful: user=%s, gate=%s:%d",
        user_info.account,
        gate_addr.host, gate_addr.port)
        
    return {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "login success",
        token = token,
        ws_addr = gate_addr.host,
        ws_port = gate_addr.port
    }
end

return M 