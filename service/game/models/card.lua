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

-- 获取用户卡牌
function M.get_user_cards(user_id)
    -- 先尝试从缓存获取
    local cards = cache.get_user_cards(user_id)
    if cards then
        logger.debug("Get user cards from cache, user_id: %d", user_id)
        return cards
    end

    -- 缓存未命中，从数据库获取
    logger.debug("Cache miss, getting cards from DB, user_id: %d", user_id)
    local db = skynet.call(".db_proxy", "lua", "get_user_cards", user_id)
    if not db then
        return nil
    end

    -- 写入缓存
    cache.set_user_cards(user_id, db)
    logger.debug("User cards cached, user_id: %d", user_id)
    return db
end

-- 更新卡牌
function M.update_card(card_info)
    -- 先更新数据库
    local ok = skynet.call(".db_proxy", "lua", "update_card", card_info)
    if not ok then
        return false
    end

    -- 清除缓存，强制下次重新加载
    cache.remove_user_cards(card_info.user_id)
    logger.debug("Card cache cleared after update, user_id: %d", card_info.user_id)
    return true
end

-- 添加卡牌
function M.add_card(card_info)
    -- 先写入数据库
    local ok = skynet.call(".db_proxy", "lua", "add_card", card_info)
    if not ok then
        return false
    end

    -- 清除缓存，强制下次重新加载
    cache.remove_user_cards(card_info.user_id)
    logger.debug("Card cache cleared after adding new card, user_id: %d", card_info.user_id)
    return true
end

return M 