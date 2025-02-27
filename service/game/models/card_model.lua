local snowflake = require "utils.snowflake"

-- 卡牌数据模型定义
local M = {}

-- 创建新卡牌模型
function M.new(params)
    local now = os.time()
    return {
        -- 基础信息
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.CARD),
        user_id = params.user_id,
        card_id = params.card_id,
        card_type = params.card_type,
        
        -- 等级相关
        level = params.level or 1,
        exp = params.exp or 0,
        star = params.star or 1,
        quality = params.quality or 1,
        
        -- 战力
        power = params.power or 0,
        
        -- 时间相关
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 验证卡牌数据
function M.validate(card_data)
    if not card_data then
        return false, "card data is empty"
    end
    
    if not card_data.user_id then
        return false, "user id is empty"
    end
    
    if not card_data.card_type then
        return false, "card type is empty"
    end
    
    return true
end

return M 