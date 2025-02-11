local skynet = require "skynet"
local logger = require "logger"
local db_client = require "game.db_client"
local cache = require "game.cache"

local M = {}

-- 初始卡牌配置
local INITIAL_CARDS = {
    {card_id = 1, level = 1},
    {card_id = 2, level = 1},
    {card_id = 3, level = 1}
}

-- 计算卡牌战力
local function calculate_power(card)
    return card.level * 100 + card.star * 50 + card.quality * 200
end

-- 初始化用户卡牌
function M.init_user_cards(user_id)
    logger.info("Initializing cards for user: %d", user_id)
    
    local current_time = os.time()
    local cards = {}
    
    -- 准备初始卡牌数据
    for _, config in ipairs(INITIAL_CARDS) do
        local card = {
            user_id = user_id,
            card_id = config.card_id,
            level = config.level,
            exp = 0,
            star = 1,
            quality = 1,
            create_time = current_time,
            update_time = current_time
        }
        card.power = calculate_power(card)
        table.insert(cards, card)
    end
    
    -- 批量创建卡牌
    local ok, err = db_client.batch_create_cards(cards)
    if not ok then
        logger.error("Failed to create initial cards: %s", err)
        return false
    end
    
    -- 缓存卡牌数据
    cache.set_user_cards(user_id, cards)
    
    return true
end

-- 获取用户卡牌列表
function M.get_user_cards(user_id)
    -- 先查缓存
    local cached = cache.card.get(user_id)
    if cached then
        return cached
    end
    
    -- 查询数据库
    local cards = db_client.get_user_cards(user_id)
    if cards then
        cache.card.set(user_id, cards)
    end
    
    return cards
end

-- 更新卡牌
function M.update_card(user_id, card_id, updates)
    -- 获取卡牌信息
    local cards = M.get_user_cards(user_id)
    if not cards then
        return false, "Failed to get cards"
    end
    
    -- 查找要更新的卡牌
    local card
    for _, c in ipairs(cards) do
        if c.id == card_id then
            card = c
            break
        end
    end
    
    if not card then
        return false, "Card not found"
    end
    
    -- 更新字段
    for k, v in pairs(updates) do
        card[k] = v
    end
    
    -- 重新计算战力
    card.power = calculate_power(card)
    card.update_time = os.time()
    
    -- 更新数据库
    local ok = db_client.update_card(card)
    if not ok then
        return false, "Failed to update card"
    end
    
    -- 更新缓存
    cache.card.remove(user_id)
    
    return true
end

return M 