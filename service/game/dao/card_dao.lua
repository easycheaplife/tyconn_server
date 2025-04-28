local skynet = require "skynet"
local logger = require "logger"
local cache = require "game.cache"
local db_client = require "game.db_client"
local utils = require "utils"
local card_model = require "models.card_model"

local M = {}

-- 获取用户卡牌
function M.get_user_cards(user_id)
    if not user_id then
        return nil, "invalid user id"
    end

    -- 1. 从缓存获取
    local cards = cache.get_user_cards(user_id)
    if cards then
        logger.debug("Got cards from cache for user %d: %s", 
            user_id, utils.table_to_string(cards))
        return cards
    end

    -- 2. 从数据库获取
    local result = db_client.get_user_cards(user_id)
    if not result then
        return nil
    end

    -- 确保每个字段都是数字类型
    for _, card in ipairs(result) do
        logger.debug("card id: %d", card.card_id)
        -- 确保是整数
        if type(card.card_id) == "string" then
            card.card_id = tonumber(card.card_id)
        end
        if type(card.card_id) == "cdata" then
            card.card_id = tonumber(tostring(card.card_id))
        end
        card.level = tonumber(card.level)
        card.exp = tonumber(card.exp)
        card.star = tonumber(card.star)
        card.quality = tonumber(card.quality)
        card.power = tonumber(card.power)
        card.create_time = tonumber(card.create_time)
        card.update_time = tonumber(card.update_time)
        card.card_type = tonumber(card.template_id) or card.card_type
    end

    -- 3. 写入缓存
    cache.set_user_cards(user_id, result)
    logger.debug("Cached cards for user %d: %s", 
        user_id, utils.table_to_string(result))

    return result
end

-- 批量创建卡牌
function M.batch_create_cards(cards)
    if not cards or #cards == 0 then
        return false, "invalid card data"
    end
    
    -- 写入数据库
    local ok, err = db_client.batch_create_cards(cards)
    if not ok then
        logger.error("Failed to create cards: %s", err)
        return false, err
    end
    
    -- 缓存卡牌数据
    if cards[1] and cards[1].user_id then
        cache.set_user_cards(cards[1].user_id, cards)
    end
    
    return true, cards
end

-- 创建卡牌
function M.create_card(card)
    return db_client.create_card(card)
end

-- 更新卡牌
function M.update_card(card)
    -- 1. 更新数据库
    local ok = db_client.update_card(card)
    if not ok then
        return false
    end

    -- 2. 清除缓存
    cache.remove_user_cards(card.user_id)
    logger.debug("Card cache cleared: %s", card.user_id)

    return true
end

return M 