local skynet = require "skynet"
local logger = require "logger"
local card_model = require "models.card_model"
local card_dao = require "dao.card_dao"
local utils = require "utils"

local M = {}

-- 初始卡牌配置
local INITIAL_CARDS = {
    {card_id = 1, card_type = 1, level = 1},
    {card_id = 2, card_type = 2, level = 1},
    {card_id = 3, card_type = 3, level = 1}
}

-- 计算卡牌战力
local function calculate_power(card)
    return card.level * 100 + card.star * 50 + card.quality * 200
end

-- 获取用户卡牌
function M.get_user_cards(user_id)
    if not user_id then
        return nil, "无效的用户ID"
    end

    -- 从dao层获取卡牌
    local cards = card_dao.get_user_cards(user_id)
    if not cards then
        -- 新用户，初始化卡牌
        return M.init_user_cards(user_id)
    end

    return cards
end

-- 初始化用户卡牌
function M.init_user_cards(user_id)
    if not user_id then
        return false, "无效的用户ID"
    end

    logger.info("Initializing cards for new user: %d", user_id)
    
    local current_time = os.time()
    local cards = {}
    
    -- 准备初始卡牌数据
    for _, config in ipairs(INITIAL_CARDS) do
        local card = card_model.new({
            user_id = user_id,
            card_id = config.card_id,
            card_type = config.card_type,
            level = config.level,
            exp = 0,
            star = 1,
            quality = 1,
            create_time = current_time,
            update_time = current_time
        })
        card.power = calculate_power(card)
        table.insert(cards, card)
    end
    
    -- 批量创建卡牌
    local ok, result = card_dao.batch_create_cards(cards)
    if not ok then
        logger.error("Failed to create initial cards: %s", result)
        return false
    end
    
    return result
end

-- 更新卡牌
function M.update_card(card)
    -- 重新计算战力
    card.power = calculate_power(card)
    card.update_time = os.time()
    
    return card_dao.update_card(card)
end

-- 添加卡牌
function M.add_card(card_info)
    -- 创建新卡牌
    local card = card_model.new(card_info)
    
    -- 计算战力
    card.power = calculate_power(card)
    
    -- 验证数据
    local ok, err = card_model.validate(card)
    if not ok then
        return false, err
    end
    
    -- 写入数据库
    local ok = card_dao.create_card(card)
    if not ok then
        return false, "添加卡牌失败"
    end

    return true
end

return M 