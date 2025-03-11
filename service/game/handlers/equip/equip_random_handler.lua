local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local equip_service = require "services.equip_service"
local handler_helper = require "game.handlers.handler_helper"
local message_helper = require "message_helper" 
local error = require "error" 
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling equip random request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GEquipRandomRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", 
            client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            error_code, 
            "command.G2CEquipRandomResponse", 
            nil, 
            message.G2C_EQUIP_RANDOM_RESPONSE)
    end
    
    -- 解析请求参数
    local part = request.part
    local is_replace = request.is_replace
    
    -- 随机获取装备
    local new_equip, error_msg, equip_config = equip_service.random_equipment(user.user_id, part)
    
    if not new_equip then
        logger.error("Failed to get random equipment for user: %d, error: %s", 
            user.user_id, error_msg)
        return message_helper.create_error_response(
            base_request, 
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            "command.G2CEquipRandomResponse", 
            nil, 
            message.G2C_EQUIP_RANDOM_RESPONSE)
    end
    
    -- 获取当前部位的装备
    local equipments = equip_service.get_equipments(user.user_id)
    local current_equip = equipments and equipments[part]
    
    -- 计算战力差值
    local power_diff = 0
    if current_equip then
        local current_power = equip_service.get_equipment_power_one(current_equip)
        local new_power = equip_service.get_equipment_power_one(new_equip)
        power_diff = new_power - current_power
    else
        power_diff = equip_service.get_equipment_power_one(new_equip)
    end
    
    -- 转换新装备信息
    local new_equip_info = {
        id = new_equip.id,
        item_id = new_equip.item_id,
        count = new_equip.count,
        bag_type = new_equip.bag_type,
        slot_index = new_equip.slot_index,
        bind_type = new_equip.bind_type,
        expire_time = new_equip.expire_time,
        level = new_equip.level,
        quality = new_equip.quality,
        enhance_level = new_equip.enhance_level,
        refine_level = new_equip.refine_level,
        gem_slots = new_equip.gem_slots,
        props = new_equip.props,
        extra_data = new_equip.extra_data
    }
    
    -- 转换当前装备信息
    local current_equip_info = nil
    if current_equip then
        current_equip_info = {
            id = current_equip.id,
            item_id = current_equip.item_id,
            count = current_equip.count,
            bag_type = current_equip.bag_type,
            slot_index = current_equip.slot_index,
            bind_type = current_equip.bind_type,
            expire_time = current_equip.expire_time,
            level = current_equip.level,
            quality = current_equip.quality,
            enhance_level = current_equip.enhance_level,
            refine_level = current_equip.refine_level,
            gem_slots = current_equip.gem_slots,
            props = current_equip.props,
            extra_data = current_equip.extra_data
        }
    end
    
    -- 构造响应数据
    local response_data = {
        new_equip = new_equip_info,
        current_equip = current_equip_info,
        power_diff = power_diff
    }
    
    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CEquipRandomResponse",
        response_data,
        message.G2C_EQUIP_RANDOM_RESPONSE)
end

return M