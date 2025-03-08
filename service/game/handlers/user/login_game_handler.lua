local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local user_service = require "services.user_service"
local bag_service = require "services.bag_service"
local name_generator = require "game.utils.name_generator"
local handler_helper = require "game.handlers.handler_helper"
local utils = require "utils"
local message = require "message"
local user_session_service = require "services.user_session_service"

local M = {}

function M.handle(client_id, msg, gate_node)
    logger.debug("Handling login game request from client %d", client_id)
    
    -- 验证请求
    local base_request, request, error_code, error_message, claims = handler_helper.verify_request(
        client_id, msg, "command.C2GLoginGameRequest")
    if error_code ~= pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CLoginGameResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_LOGIN_GAME_RESPONSE"))
    end

    -- 获取用户信息
    local user_info = user_service.get_user(claims.account)
    local result = {}
    local is_new_user = false

    if user_info then
        user_info.account = claims.account
        logger.debug("User found, updating login time: %s", utils.table_to_string(user_info))
        -- 更新登录时间
        user_service.update_user_login_time(user_info.user_id)
        result = {
            user = user_info
        }
    else
        logger.debug("Creating new user for account: %s", claims.account)
        
        -- 生成用户名
        local username = name_generator.generate_username()
        
        -- 使用 user_service 创建用户
        local user, err, is_new = user_service.get_or_create_user(claims.account, username)
        if not user then
            logger.error("Failed to create user: %s", err or "unknown error")
            return message.create_error_response(
                base_request, 
                pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR"), 
                "command.G2CLoginGameResponse", 
                nil, 
                pb.enum("common.MessageID", "G2C_LOGIN_GAME_RESPONSE"))
        end
        
        result = {
            user = user
        }
        is_new_user = is_new
        
        -- 如果是新用户，初始化游戏数据
        if is_new then
            user_service.init_new_user(user.user_id)
        end
    end

    -- 添加用户会话
    user_session_service.add_user(client_id, result.user, gate_node)
    
    -- 获取游戏数据
    local bags = bag_service.get_user_bags(result.user.user_id)
    local resources = user_service.get_user_resources(result.user.user_id)
    
    -- 记录登录日志
    logger.info("User %s (ID: %d) logged in to game", result.user.username, result.user.user_id)

    -- 构造响应数据
    local response_data = {
        user = {
            user_id = result.user.user_id,
            username = result.user.username,
            level = result.user.level,
            exp = result.user.exp or 0,
            gold = result.user.gold or 0,
            vip_level = result.user.vip_level or 0,
            create_time = result.user.create_time,
            login_time = result.user.login_time,
            hp = result.user.hp,
            attack = result.user.attack,
            defense = result.user.defense
        },
        is_new_user = is_new_user,
        bags = bags,
        resources = resources,
        server_time = skynet.time() * 1000  -- 服务器时间（毫秒）
    }

    return message.create_success_response(
        base_request,
        "command.G2CLoginGameResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_LOGIN_GAME_RESPONSE"))
end

return M 