local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local jwt = require "jwt"
local name_generator = require "game.utils.name_generator"
local utils = require "utils"
local db_client = require "game.db_client"
local user = require "game.models.user"
local card = require "game.models.card"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling user info request from client %d", client_id)
    
    -- 解码请求
    local base_request, request = message.decode_request(msg, "command.C2GUserInfoRequest")
    if not base_request then
        return nil
    end

    -- 验证Token
    local token_result = message.verify_token(request.token)
    if token_result.code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        logger.error("Failed to decode token: %s", token_result.message)
        return message.create_error_response(base_request.session, 
            pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"), 
            "Invalid token")
    end

    -- 先尝试获取用户信息
    local response = db_client.get_user(token_result.claims.account)
    if not response then
        logger.error("Failed to get user for account %s", token_result.claims.account)
        return message.create_error_response(base_request.session,
            pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
            "Database error")
    end

    -- 如果用户不存在，则创建用户
    if not response.user then
        logger.debug("Creating new user for account: %s", token_result.claims.account)
        
        -- 创建用户数据
        local new_user = {
            account = token_result.claims.account,
            username = name_generator.generate_username(),
            level = 1,
            exp = 0,
            vip_level = 0,
            create_time = os.time(),
            last_login = os.time()
        }
        
        logger.debug("Creating new user: %s", utils.table_to_string(new_user))

        -- 使用 db_client 创建用户
        local success, err, is_new = db_client.create_user(new_user)
        if not success then
            logger.error("Failed to create user: %s", err)
            return message.create_error_response(base_request.session,
                pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
                err or "创建用户失败")
        end
        
        response = {
            user = err,  -- db_client.create_user 返回的用户信息
            is_new = is_new or true
        }
    end
    
    -- 如果是新用户，初始化卡牌
    if response.is_new then
        local ok = card.init_user_cards(response.user.user_id)
        if not ok then
            logger.error("Failed to initialize cards for new user: %s", token_result.claims.account)
            -- 继续返回用户信息，不影响登录流程
        end
    end
    
    -- 创建基础响应
    local base_response = message.create_base_response(base_request.session,
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "Success",
        pb.encode("command.G2CUserInfoResponse", response))
    
    -- 设置正确的响应消息ID
    base_response.session.messageId = pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE")

    -- 编码并返回响应
    return pb.encode("common.BaseResponse", base_response)
end

return M 