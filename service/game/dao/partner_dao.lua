local skynet = require "skynet"
local logger = require "logger"
local cache = require "game.cache"
local db_client = require "game.db_client"
local utils = require "utils"
local partner_model = require "models.partner_model"
local table_service = require "game.services.table_service"

local M = {}

-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    if not user_id then
        return nil, "invalid user id"
    end

    -- 1. 从缓存获取
    local partners = cache.get_user_partners(user_id)
    if partners then
        logger.debug("Got partners from cache for user %d: %s", 
            user_id, utils.table_to_string(partners))
        return partners
    end

    -- 2. 从数据库获取
    local result = db_client.get_user_partners(user_id)
    if not result then
        return nil
    end

    -- 确保每个字段都是数字类型并从配置中读取一些字段
    for _, partner in ipairs(result) do
        logger.debug("partner id: %d", partner.id)
        -- 确保是整数
        if type(partner.id) == "string" then
            partner.id = tonumber(partner.id)
        end
        if type(partner.id) == "cdata" then
            partner.id = tonumber(tostring(partner.id))
        end
        partner.unit_id = tonumber(partner.unit_id)
        partner.level = tonumber(partner.level)
        partner.exp = tonumber(partner.exp)
        partner.star = tonumber(partner.star)
        partner.power = tonumber(partner.power)
        partner.create_time = tonumber(partner.create_time)
        partner.update_time = tonumber(partner.last_update_time)
        
        -- 从配置中读取quality、race和forte
        local unit_config = table_service.get_unit_config(partner.unit_id)
        if unit_config then
            partner.quality = tonumber(unit_config.quality) or 1
            partner.race = tonumber(unit_config.race) or 0
            partner.forte = tonumber(unit_config.forte) or 0
        else
            logger.error("Failed to get unit config for unit_id: %d", partner.unit_id)
            partner.quality = 1
            partner.race = 0
            partner.forte = 0
        end
        
        -- 确保属性数组存在
        if not partner.properties then
            partner.properties = {}
        end
    end

    -- 3. 写入缓存
    cache.set_user_partners(user_id, result)
    logger.debug("Cached partners for user %d: %s", 
        user_id, utils.table_to_string(result))

    return result
end

-- 获取单个伙伴
function M.get_partner(partner_id)
    if not partner_id then
        return nil, "invalid partner id"
    end
    
    -- 1. 从缓存获取
    local partner = cache.get_partner(partner_id)
    if partner then
        logger.debug("Got partner from cache: %s", utils.table_to_string(partner))
        return partner
    end
    
    -- 2. 从数据库获取
    local result = db_client.get_partner(partner_id)
    if not result then
        return nil
    end
    
    -- 3. 写入缓存
    cache.set_partner(partner_id, result)
    logger.debug("Cached partner: %s", utils.table_to_string(result))
    
    return result
end

-- 批量创建伙伴
function M.batch_create_partners(partners)
    if not partners or #partners == 0 then
        return false, "invalid partner data"
    end
    
    -- 写入数据库
    local ok, err = db_client.batch_create_partners(partners)
    if not ok then
        logger.error("Failed to create partners: %s", err)
        return false, err
    end
    
    -- 缓存伙伴数据
    if partners[1] and partners[1].user_id then
        cache.set_user_partners(partners[1].user_id, partners)
    end
    
    return true, partners
end

-- 创建伙伴
function M.create_partner(partner)
    -- 1. 写入数据库
    local ok = db_client.create_partner(partner)
    if not ok then
        return false
    end
    
    -- 2. 清除用户伙伴列表缓存
    cache.remove_user_partners(partner.user_id)
    logger.debug("Partner list cache cleared for user: %s", partner.user_id)
    
    -- 3. 设置伙伴缓存
    cache.set_partner(partner.id, partner)
    logger.debug("Partner cached: %s", utils.table_to_string(partner))
    
    return true
end

-- 更新伙伴
function M.update_partner(partner)
    -- 1. 更新数据库
    local ok = db_client.update_partner(partner)
    if not ok then
        return false
    end

    -- 2. 清除缓存
    cache.remove_user_partners(partner.user_id)
    cache.remove_partner(partner.id)
    logger.debug("Partner cache cleared: %s", partner.id)

    return true
end

-- 删除伙伴
function M.delete_partner(partner_id, user_id)
    if not partner_id or not user_id then
        return false, "missing partner_id or user_id"
    end
    
    -- 1. 从数据库删除
    local ok = db_client.delete_partner(partner_id)
    if not ok then
        return false
    end
    
    -- 2. 清除缓存
    cache.remove_user_partners(user_id)
    cache.remove_partner(partner_id)
    logger.debug("Partner cache cleared: %s", partner_id)
    
    return true
end

return M 