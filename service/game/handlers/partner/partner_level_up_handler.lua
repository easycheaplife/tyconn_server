local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local message_helper = require "message_helper" 
local partner_service = require "services.partner_service"
local bag_service = require "services.bag_service"
local handler_helper = require "game.handlers.handler_helper"
local utils = require "utils"
local error = require "error"   
local message = require "message"

local M = {}

function M.handle(client_id, msg)
    logger.debug("Handling partner level up request from client %d", client_id)
    
    -- 验证请求并获取用户信息
    local base_request, request, error_code, error_message, user, claims = handler_helper.verify_request_with_user(
        client_id, msg, "command.C2GPartnerLevelUpRequest")
    if error_code ~= error.ErrorCode.ERROR_CODE_SUCCESS then
        logger.error("Failed to verify request for client: %d, error_code: %s, error_message: %s", client_id, error_code, error_message)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerLevelUpResponse",
            error_code, 
            error_message, 
            message.MessageID.G2C_PARTNER_LEVEL_UP_RESPONSE)
    end

    -- 检查参数
    if not request.partner_id then
        logger.error("Missing partner_id in request")
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerLevelUpResponse",
            error.ErrorCode.ERROR_CODE_INVALID_PARAMETER, 
            "Missing partner_id", 
            message.MessageID.G2C_PARTNER_LEVEL_UP_RESPONSE)
    end

    -- 升级伙伴
    local result, updated_partner, property_changes, consumed_items = partner_service.level_up_partner(user.user_id, request.partner_id)
    if not result then
        logger.error("Failed to level up partner for user: %d, partner_id: %d", user.user_id, request.partner_id)
        return message_helper.create_error_response(
            base_request, 
            "command.G2CPartnerLevelUpResponse",
            error.ErrorCode.ERROR_CODE_SYSTEM_ERROR, 
            nil, 
            message.MessageID.G2C_PARTNER_LEVEL_UP_RESPONSE)
    end

    -- 获取最新的背包信息
    local bags = bag_service.get_user_bags(user.user_id)
    if not bags then
        logger.error("Failed to get bags for user: %d", user.user_id)
        return message_helper.create_error_response(
            base_request,
            "command.G2CPartnerLevelUpResponse",
            error.ErrorCode.ERROR_CODE_GET_BAG_FAILED,
            "Failed to get bags",
            message.MessageID.G2C_PARTNER_LEVEL_UP_RESPONSE)
    end
    
    -- 只返回包含变化物品的背包信息
    local changed_bags = {}
    for _, bag in ipairs(bags) do
        if bag.bag_type == pb.enum("common.BagType", "BAG_TYPE_MAIN") then
            local changed_items = {}
            for _, bag_item in ipairs(bag.items) do
                -- 检查是否是消耗的物品
                for _, consumed_item in ipairs(consumed_items) do
                    if bag_item.item_id == consumed_item.item_id then
                        table.insert(changed_items, {
                            slot = bag_item.slot,
                            item_id = bag_item.item_id,
                            count = bag_item.count
                        })
                        break
                    end
                end
            end
            if #changed_items > 0 then
                table.insert(changed_bags, {
                    size = bag.size,
                    bag_type = bag.bag_type,
                    items = changed_items
                })
            end
        end
    end

    -- 构造响应数据
    local response_data = {
        partner = updated_partner,
        property_changes = property_changes,
        consumed_items = consumed_items,
        bags = changed_bags
    }

    logger.debug("Sending partner level up response: %s", utils.table_to_string(response_data))

    -- 返回成功响应
    return message_helper.create_success_response(
        base_request,
        "command.G2CPartnerLevelUpResponse",
        response_data,
        message.MessageID.G2C_PARTNER_LEVEL_UP_RESPONSE)
end

return M 