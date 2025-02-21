local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local websocket = require "http.websocket"
local login_handler = require "login.handlers.login_handler"
local utils = require "utils"

local M = {}
local clients = {}  -- client_id -> session info

-- 发送错误响应
local function send_error_response(client_id, session, message, error_code)
    logger.error("send_error_response: client_id=%d, session=%s, message=%s, error_code=%s", 
        client_id, utils.table_to_string(session), utils.table_to_string(message), error_code)
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
    logger.debug("send_login_response: client_id=%d, session=%s, data=%s", 
        client_id, utils.table_to_string(session), utils.table_to_string(data))
    local ok, payload = pcall(pb.encode, "command.L2CLoginResponse", data)
    if not ok then
        logger.error("Failed to encode login response: %s", payload)
        send_error_response(client_id, session, "系统错误")
        return
    end
    
    local base_response = {
        session = session,
        errorCode = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        errorMsg = data.message,
        payload = payload
    }
    
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", base_response)
    if ok then
        websocket.write(client_id, encoded, "binary")
    else
        logger.error("Failed to encode base response: %s", encoded)
    end
end

-- 处理新连接
function M.connect(client_id)
    clients[client_id] = {
        connect_time = os.time()
    }
    logger.debug("Client %d connected", client_id)
end

-- 处理消息
function M.message(client_id, msg, msg_type)
    if msg_type ~= "binary" then
        logger.warn("Received non-binary message from client %d", client_id)
        return
    end

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

    -- 处理登录请求
    local result = login_handler.handle(client_id, base_request)
    if result.code == pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        send_login_response(client_id, base_request.session, result)
    else
        send_error_response(client_id, base_request.session, result.message, result.code)
    end
end

-- 处理连接关闭
function M.close(client_id)
    logger.debug("Client %d disconnected", client_id)
    clients[client_id] = nil
end

return M 