-- gate_client.lua - 网关客户端模块，用于向客户端推送消息
local skynet = require "skynet"
local logger = require "logger"
local user_session_service = require "services.user_session_service"
local utils = require "utils"
local message_helper = require "message_helper" 
local pb = require "pb"
local cluster = require "skynet.cluster"

local M = {}

-- 消息ID到类型的映射表
local MESSAGE_TYPE_MAP = {
    [551] = "command.G2CNewMailPush",              -- 新邮件推送
    [451] = "command.G2CEquipmentExpiredPush",     -- 装备过期推送
    [452] = "command.G2CEquipmentLevelUpgradedPush" -- 装备等级升级完成推送
    -- 可以根据需要添加更多映射
}

-- 推送消息到指定用户
function M.push_message(user_id, message_id, message_data)
    logger.info("push_message: user_id: %s, message_id: %s", user_id, message_id)
    
    -- 尝试从用户会话获取网关地址
    local session = user_session_service.get_session_by_user_id(user_id)
    if not session then
        logger.warn("push_message: User %d not found in session", user_id)
        return false
    end
    logger.info("push_message: session: %s", utils.table_to_string(session))
    if not session.gate_node then
        logger.warn("push_message: User %d has no gate_node in session", user_id)
        return false
    end
    
    -- 获取节点名称
    local node_name = session.gate_node
    logger.debug("Gate node for user %d: %s", user_id, node_name)
    
    -- 使用message模块创建会话信息
    local session_info = message_helper.create_session(message_id, 0, "1.0.0")
    
    -- 编码消息负载
    local payload = ""
    if type(message_data) == "table" then
        -- 获取对应的Proto类型
        local proto_type = MESSAGE_TYPE_MAP[message_id]
        if proto_type then
            -- 使用正确的Proto类型编码消息
            local ok, encoded = pcall(pb.encode, proto_type, message_data)
            if ok then
                payload = encoded
                logger.debug("Encoded message payload using %s", proto_type)
            else
                logger.warn("Failed to encode message payload: %s", encoded)
                return false
            end
        else
            logger.warn("No proto type mapping found for message ID %d", message_id)
            return false
        end
    else
        -- 如果已经是二进制数据，直接使用
        payload = message_data
    end
    
    -- 创建基础响应
    local response = message_helper.create_base_response(
        session_info,
        pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        "",
        payload
    )
    
    -- 编码响应
    local encoded_response = message_helper.encode_response(response)
    
    -- 发送消息
    local ok, err
    local current_node = skynet.getenv("node_name")
    
    -- 远程节点，使用集群通信
    logger.debug("Sending to remote gate manager on node %s for client %d", node_name, session.client_id)
    ok, err = pcall(cluster.send, node_name, "@" .. node_name, "client_push", session.client_id, message_id, encoded_response)
    
    if not ok then
        logger.error("Failed to push message to client %d: %s", session.client_id, tostring(err))
        return false
    end
    
    logger.info("Successfully pushed message to client %d", session.client_id)
    return true
end

-- 批量推送消息到指定用户列表
function M.push_message_to_users(user_ids, message_id, message_data)
    if not user_ids or #user_ids == 0 then
        return true
    end
    
    local result = true
    for _, user_id in ipairs(user_ids) do
        local ok = M.push_message(user_id, message_id, message_data)
        if not ok then
            result = false
        end
    end
    
    return result
end

-- 广播消息到所有在线用户
function M.broadcast_message(message_id, message_data)
    local online_users = user_session_service.get_all_online_user_ids()
    return M.push_message_to_users(online_users, message_id, message_data)
end

return M 