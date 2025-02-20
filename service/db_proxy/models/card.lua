local skynet = require "skynet"
local logger = require "logger"
local sql = require "db_proxy.sql.card"
local db_util = require "db_proxy.utils.db_util"

local M = {}

-- 批量创建卡牌
function M.batch_create_cards(cards)
    if not cards or #cards == 0 then
        return false, "No cards to create"
    end
    
    for _, card in ipairs(cards) do
        -- 插入数据库
        local query = string.format(sql.INSERT_CARD,
            card.id,
            card.user_id,
            card.card_id,
            card.level,
            card.exp,
            card.star,
            card.quality,
            card.power,
            card.create_time,
            card.update_time
        )
        
        local ok = db_util.query(query)
        if not ok then
            logger.error("Failed to insert card for user: %d, card_id: %d",
                card.user_id, card.card_id)
            return false, "Database error"
        end
    end
    
    return true
end

-- 获取用户卡牌列表
function M.get_user_cards(user_id)
    local query = string.format(sql.GET_USER_CARDS, user_id)
    local results = db_util.query(query)
    
    if not results then
        logger.error("Failed to get cards for user: %d", user_id)
        return nil, "Database error"
    end
    
    -- 确保返回所有必要字段
    for _, card in ipairs(results) do
        card.card_type = card.card_type or 1  -- 默认类型
        card.exp = card.exp or 0
        card.power = card.power or 0
    end
    
    return results
end

-- 更新卡牌信息
function M.update_card(card)
    if not card or not card.id or not card.user_id then
        return false, "Invalid card info"
    end
    
    local query = string.format(sql.UPDATE_CARD,
        card.level,
        card.exp,
        card.star,
        card.quality,
        card.power,
        card.update_time,
        card.id,
        card.user_id
    )
    
    local ok = db_util.query(query)
    if not ok then
        return false, "Database error"
    end
    
    return true
end

-- 创建卡牌
function M.create_card(card)
    if not card or not card.id or not card.user_id then
        return false, "Invalid card info"
    end
    
    local query = string.format(sql.CREATE_CARD,
        card.id,
        card.user_id,
        card.card_id,
        card.card_type,
        card.level,
        card.exp,
        card.star,
        card.quality,
        card.power,
        card.create_time,
        card.update_time
    )
    
    local ok = db_util.query(query)
    if not ok then
        return false, "Database error"
    end
    
    return true
end

return M 