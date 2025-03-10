local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local equip_service = require "services.equip_service"
local handler_helper = require "game.handlers.handler_helper"
local message = require "message"
local utils = require "utils"
local error = require "game.define.error"  

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling unequip item request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GUnequipItemRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CUnequipItemResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_UNEQUIP_ITEM_RESPONSE"))
    end

    -- 解析请求参数
    local equip_slot = request.equip_slot
    local bag_type = request.bag_type
    local slot_index = request.slot_index or 0 -- 0表示自动选择
    
    -- 卸下装备
    local result, error_msg, unequipped_item, power_change = 
        equip_service.unequip_item(user.user_id, equip_slot, bag_type, slot_index)
    
    if not result then
        logger.error("Failed to unequip item for user: %d, error: %s", 
            user.user_id, error_msg)
        return message.create_error_response(
            base_request, 
            error.ErrorCode.ERROR_CODE_INVALID_OPERATION, 
            "command.G2CUnequipItemResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_UNEQUIP_ITEM_RESPONSE"))
    end
    
    -- 转换卸下项
    local unequipped_item_info = nil
    if unequipped_item then
        unequipped_item_info = {
            id = unequipped_item.id,
            item_id = unequipped_item.item_id,
            count = unequipped_item.count,
            bag_type = unequipped_item.bag_type,
            slot_index = unequipped_item.slot_index,
            bind_type = unequipped_item.bind_type,
            expire_time = unequipped_item.expire_time,
            enhance_level = unequipped_item.enhance_level,
            refine_level = unequipped_item.refine_level,
            gem_slots = unequipped_item.gem_slots,
            props = unequipped_item.props,
            extra_data = unequipped_item.extra_data
        }
    end
    
    -- 构造响应数据
    local response_data = {
        unequipped_item = unequipped_item_info,
        combat_power_change = power_change
    }
    
    -- 返回成功响应
    return message.create_success_response(
        base_request,
        "command.G2CUnequipItemResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_UNEQUIP_ITEM_RESPONSE"))
end

return M 