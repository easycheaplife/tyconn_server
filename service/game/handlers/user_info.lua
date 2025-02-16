local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message = require "message"
local card = require "game.models.card"
local item = require "game.models.item"
local user = require "game.models.user"  -- 改用 user model
local session = require "game.models.session"
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
    local result = user.get_user_from_cache(claims.account)
    -- 确保 result 的结构一致
    if result then
        result = { user = result }
    end

    if not result then
        -- 缓存中没有，从数据库获取
        result = user.get_user(claims.account)
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
            local cache_success, cache_err = user.cache_user(result.user)
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

            -- 使用 user.create_user 创建用户
            local success, created_user, is_new = user.create_user(new_user)
            if not success then
                logger.error("Failed to create user: %s", created_user or "unknown error")
                return message.encode_response(message.create_error_response(base_request.session,
                    pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"),
                    created_user or "创建用户失败"))
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
        }
    }

    return handler_helper.create_success_response(
        base_request,
        "command.G2CUserInfoResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_USER_INFO_RESPONSE"))
end

return M