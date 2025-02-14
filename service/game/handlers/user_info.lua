local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local card = require "game.models.card"
local user_mgr = require "game.user_mgr"
local db_client = require "game.db_client"
local name_generator = require "game.utils.name_generator"
local handler_helper = require "game.handlers.handler_helper"
local utils = require "utils"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling user info request from client %d", client_id)
    
    -- 验证请求
    local base_request, request, claims = handler_helper.verify_request(
        client_id, msg, "command.C2GUserInfoRequest")
    if not base_request then
        return request  -- 错误响应
    end

    -- 先从缓存获取用户信息
    local result = user_mgr.get_user_from_cache(claims.account)
    if not result then
        -- 缓存中没有，从数据库获取
        result = user_mgr.get_user(claims.account)
        if not result then
            logger.error("Failed to get user for account %s", claims.account)
            return message.encode_response(message.create_error_response(base_request.session,
                pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
                "Database error"))
        end

        -- 如果用户存在，将用户信息存入缓存
        if result.user then
            result.user.account = claims.account
            logger.debug("Attempting to cache user data: %s", utils.table_to_string(result.user))
            local cache_success, cache_err = user_mgr.cache_user(result.user)
            if not cache_success then
                logger.error("Failed to cache user data: %s", cache_err or "unknown error")
                -- 继续处理，不影响用户信息返回
            end
        end

        -- 如果用户不存在，则创建用户
        if not result.user then
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

            -- 使用 db_client 创建用户
            local success, err, is_new = db_client.create_user(new_user)
            if not success then
                logger.error("Failed to create user: %s", err)
                return message.encode_response(message.create_error_response(base_request.session,
                    pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
                    err or "创建用户失败"))
            end
            
            result = {
                user = err,  -- db_client.create_user 返回的用户信息
                is_new = is_new or true
            }
        end

        -- 如果是新用户，初始化卡牌
        if result.is_new then
            local ok = card.init_user_cards(result.user.user_id)
            if not ok then
                logger.error("Failed to initialize cards for new user: %s", claims.account)
                -- 继续返回用户信息，不影响登录流程
            end
        end
    end

    return handler_helper.create_success_response(
        base_request,
        "command.G2CUserInfoResponse",
        result,
        pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE"))
end

return M