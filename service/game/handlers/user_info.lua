local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local card = require "game.models.card"
local item = require "game.models.item"
local user = require "game.models.user"  -- 改用 user model
local session = require "game.models.session"
local name_generator = require "game.utils.name_generator"
local handler_helper = require "game.handlers.handler_helper"
local utils = require "utils"
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling user info request from client %d", client_id)
    
    -- 验证请求
    local base_request, request, error_code, error_message, claims = handler_helper.verify_request(
        client_id, msg, "command.C2GUserInfoRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CUserInfoResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE"))
    end

    local user_info = user.get_user(claims.account)
    local result = {}

    if user_info then
        user_info.account = claims.account
        logger.debug("Attempting to cache user data: %s", utils.table_to_string(user_info))
        result = {
            user = user_info,
            is_new = false
        }
    end

    -- 如果用户不存在，则创建用户
    if not user_info then
        logger.debug("Creating new user for account: %s", claims.account)
        
        -- 创建用户数据
        local new_user = {
            account = claims.account,
            username = name_generator.generate_username(),
            level = 1,
            exp = 0,
            vip_level = 0,
            create_time = os.time(),
            last_login = os.time()
        }
        
        logger.debug("Creating new user: %s", utils.table_to_string(new_user))

        -- 使用 user.create_user 创建用户
        local success, created_user, is_new = user.create_user(new_user)
        if not success then
            logger.error("Failed to create user: %s", created_user or "unknown error")
            return message.create_error_response(
                base_request, 
                pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
                "command.G2CUserInfoResponse", 
                nil, 
                pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE"))
        end
        
        result = {
            user = created_user,  -- user.create_user 返回的用户信息
            is_new = is_new or true
        }
    end

    -- 如果是新用户，初始化游戏数据
    if result.is_new then
        -- 1. 初始化卡牌
        local ok = card.init_user_cards(result.user.user_id)
        if not ok then
            logger.error("Failed to initialize cards for new user: %s", claims.account)
            -- 继续处理，不影响登录流程
        end

        -- 2. 初始化物品
        local ok = item.init_user_items(result.user.user_id)
        if not ok then
            logger.error("Failed to initialize items for new user: %s", claims.account)
            -- 继续处理，不影响登录流程
        end
    end

    -- 打印最终的用户数据结构
    logger.debug("Final user data: %s", utils.table_to_string(result))

    -- 构造符合 protobuf 定义的响应数据
    local response_data = {
        user = {
            user_id = result.user.user_id,
            username = result.user.username,
            level = result.user.level,
            exp = result.user.exp or 0,
            vip_level = result.user.vip_level or 0,
            create_time = result.user.create_time,
            login_time = result.user.login_time
        },
        is_new = result.is_new
    }

    return message.create_success_response(
        base_request,
        "command.G2CUserInfoResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE"))
end

return M