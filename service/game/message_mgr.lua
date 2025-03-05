local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local pb = require "pb"
local protoloader = require "protoloader"

local M = {}
local handlers = {}  -- 消息处理器映射表

-- 注册消息处理器
function M.register(msg_id, handler)
    if handlers[msg_id] then
        logger.warn("Handler for message %d already exists, overwriting", msg_id)
    end
    handlers[msg_id] = handler
end

-- 初始化消息处理器
function M.init()
    -- 先加载 proto 文件
    if not protoloader.load_directory("./proto") then
        logger.error("Failed to load proto files")
        return false
    end
    logger.info("Proto files loaded")

    -- 注册处理器
    M.register(pb.enum("common.MessageID", "C2G_USER_INFO_REQUEST"), 
        require "game.handlers.user_info_handler")
    M.register(pb.enum("common.MessageID", "C2G_HEARTBEAT_REQUEST"), 
        require "game.handlers.heartbeat_handler")
    M.register(pb.enum("common.MessageID", "C2G_USER_CARDS_REQUEST"), 
        require "game.handlers.user_cards_handler")
    M.register(pb.enum("common.MessageID", "C2G_BAG_INFO_REQUEST"),
        require "game.handlers.bag_info_handler")
    M.register(pb.enum("common.MessageID", "C2G_USE_ITEM_REQUEST"),
        require "game.handlers.use_item_handler")
    M.register(pb.enum("common.MessageID", "C2G_EXPAND_BAG_REQUEST"),
        require "game.handlers.expand_bag_handler")
    M.register(pb.enum("common.MessageID", "C2G_SORT_BAG_REQUEST"),
        require "game.handlers.sort_bag_handler")
    M.register(pb.enum("common.MessageID", "C2G_GM_COMMAND_REQUEST"),
        require "game.handlers.gm_command_handler")
    M.register(pb.enum("common.MessageID", "C2G_MOVE_ITEM_REQUEST"),
        require "game.handlers.move_item_handler")
    M.register(pb.enum("common.MessageID", "C2G_COMPOSE_ITEM_REQUEST"), 
        require "game.handlers.compose_item_handler")
    M.register(pb.enum("common.MessageID", "C2G_DECOMPOSE_ITEM_REQUEST"),
        require "game.handlers.decompose_item_handler")
    M.register(pb.enum("common.MessageID", "C2G_EQUIP_INFO_REQUEST"), 
        require "game.handlers.equip_info_handler")
    M.register(pb.enum("common.MessageID", "C2G_EQUIP_ITEM_REQUEST"), 
        require "game.handlers.equip_item_handler")
    M.register(pb.enum("common.MessageID", "C2G_UNEQUIP_ITEM_REQUEST"), 
        require "game.handlers.unequip_item_handler")
    M.register(pb.enum("common.MessageID", "C2G_EQUIP_RANDOM_REQUEST"), 
        require "game.handlers.equip_random_handler")
    M.register(pb.enum("common.MessageID", "C2G_EQUIP_LEVEL_INFO_REQUEST"), 
        require "game.handlers.equip_level_info_handler")
    M.register(pb.enum("common.MessageID", "C2G_EQUIP_LEVEL_UPGRADE_REQUEST"), 
        require "game.handlers.equip_level_upgrade_handler")
    M.register(pb.enum("common.MessageID", "C2G_MAIL_LIST_REQUEST"), 
        require "game.handlers.mail.get_mail_list_handler")
    M.register(pb.enum("common.MessageID", "C2G_READ_MAIL_REQUEST"), 
        require "game.handlers.mail.read_mail_handler")
    M.register(pb.enum("common.MessageID", "C2G_CLAIM_MAIL_ITEMS_REQUEST"), 
        require "game.handlers.mail.claim_mail_items_handler")
    M.register(pb.enum("common.MessageID", "C2G_DELETE_MAIL_REQUEST"), 
        require "game.handlers.mail.delete_mail_handler")
    logger.info("Message handlers initialized")
    return true
end

-- 处理客户端消息
function M.handle_message(source, client_id, msg, gate_node)
    logger.debug("Handling message from client %d", client_id)
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok or not base_request then
        logger.error("Failed to decode base request: %s", base_request)
        return
    end
    
    -- 验证会话信息
    if not base_request.session then
        logger.error("No session in request")
        return
    end
    
    -- 打印会话信息
    logger.debug("Session info: messageId=%d, sequence=%d, timestamp=%d, version=%s",
        base_request.session.messageId or 0,
        base_request.session.sequence or 0,
        base_request.session.timestamp or 0,
        base_request.session.version or ""
    )
    
    -- 处理消息
    local msg_id = base_request.session.messageId
    local handler = handlers[msg_id]
    if handler then
        logger.debug("Found handler for message %d", msg_id)
        local response = handler.handle(client_id, msg)
        if response then
            logger.debug("Sending response back to gate")
            cluster.send(gate_node, source, "client_message", response)
        else
            logger.warn("Handler returned no response")
        end
    else
        logger.error("Unknown message id: %d", msg_id)
    end
end

return M 