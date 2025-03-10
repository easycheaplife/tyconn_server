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
    logger.debug("Handling equip info request from client %d", client_id)
    
    -- 验证请求
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GEquipInfoRequest")
    
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        return message.create_error_response(
            base_request, 
            error_code, 
            "command.G2CEquipInfoResponse", 
            nil, 
            pb.enum("common.MessageID", "G2C_EQUIP_INFO_RESPONSE"))
    end
    
    -- 获取装备列表
    local equipments = equip_service.get_equipments(user.user_id)
    
    -- 转换为协议结构
    local equipped_items = {}
    for slot, equip in pairs(equipments) do
        table.insert(equipped_items, {
            id = equip.id,
            item_id = equip.item_id,
            count = equip.count,
            bag_type = equip.bag_type,
            slot_index = equip.slot_index,
            bind_type = equip.bind_type,
            expire_time = equip.expire_time,
            level = equip.level,
            quality = equip.quality,
            enhance_level = equip.enhance_level,
            refine_level = equip.refine_level,
            gem_slots = equip.gem_slots,
            props = equip.props,
            extra_data = equip.extra_data
        })
    end
    
    -- 计算装备总战力
    local combat_power = equip_service.get_equipment_power(user.user_id)
    
    -- 构造响应
    local response_data = {
        equipped_items = equipped_items,
        combat_power = combat_power
    }
    
    return message.create_success_response(
        base_request,
        "command.G2CEquipInfoResponse",
        response_data,
        pb.enum("common.MessageID", "G2C_EQUIP_INFO_RESPONSE"))
end

return M 