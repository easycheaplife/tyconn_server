local M = {}

-- 卡包缓存
local card_cache = {}
local CARD_CACHE_EXPIRE = 300  -- 5分钟过期

function M.get_user_cards(user_id)
    local cache_key = string.format("cards:%d", user_id)
    local cache_data = card_cache[cache_key]
    
    if cache_data and os.time() - cache_data.time < CARD_CACHE_EXPIRE then
        return cache_data.cards
    end
    
    return nil
end

function M.set_user_cards(user_id, cards)
    local cache_key = string.format("cards:%d", user_id)
    card_cache[cache_key] = {
        cards = cards,
        time = os.time()
    }
end

function M.clear_user_cards(user_id)
    local cache_key = string.format("cards:%d", user_id)
    card_cache[cache_key] = nil
end

-- ... 其他缓存代码 ...

return M 