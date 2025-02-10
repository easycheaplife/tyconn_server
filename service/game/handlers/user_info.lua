local skynet = require "skynet"
local pb = require "pb"
local logger = require "logger"
local message = require "message"
local jwt = require "jwt"
local cluster = require "skynet.cluster"
local name_generator = require "game.utils.name_generator"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling user info request from client %d", client_id)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end
    
    -- 解码请求
    local ok, request = pcall(pb.decode, "command.C2GUserInfoRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode user info request: %s", request)
        return nil
    end
    
    logger.debug("Processing user info request with token: %s", request.token)
    
    -- 解析token
    local ok, claims = pcall(jwt.decode, request.token, skynet.getenv("jwt_secret"))
    if not ok or not claims then
        logger.error("Failed to decode token: %s", claims)
        return message.create_error_response(base_request.session, 
            pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"), 
            "Invalid token")
    end
    
    -- 先尝试获取用户信息
    local ok, response = pcall(cluster.call, "db_proxy", "@db_proxy", "get_user", claims.account)
    if not ok then
        logger.error("Failed to get user for account %s: %s", claims.account, response)
        return message.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
            "Database error")
    end
    
    -- 初始化响应数据
    local user_response = {
        user = response.user,
        is_new = false
    }
    
    -- 如果用户不存在，则创建用户
    if not user_response.user then
        logger.debug("Creating new user for account: %s", claims.account)
        
        -- 创建用户数据
        local user = {
            account = claims.account,
            username = name_generator.generate_username(),
            level = 1,
            exp = 0,
            vip_level = 0,
            create_time = os.time(),
            last_login = os.time()
        }
        
        logger.debug("Creating new user: %s", utils.table_to_string(user))
        
        -- 调用数据库服务创建用户
        local ok, success, err, is_new = pcall(cluster.call, "db_proxy", "@db_proxy", "create_user", user)
        if not ok then
            logger.error("Failed to create user: %s", success)
            return message.create_error_response(base_request.session,
                pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
                success or "创建用户失败")
        end
        
        if success then
            user_response = {
                user = err,
                is_new = is_new or true  -- 确保新创建的用户 is_new 为 true
            }
        else
            logger.error("Failed to create user: %s", err)
            return message.create_error_response(base_request.session,
                pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
                err or "创建用户失败")
        end
    end
    
    -- 创建基础响应
    local base_response = message.create_base_response(base_request.session,
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "Success",
        pb.encode("command.G2CUserInfoResponse", user_response))
    
    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE")
    
    -- 编码并返回响应
    return pb.encode("common.BaseResponse", base_response)
end

return M 