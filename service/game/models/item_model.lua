local snowflake = require "utils.snowflake"
local enum = require "enum"

-- 物品数据模型定义
local M = {}

-- 创建新物品模型
function M.new(params)
    local now = os.time()
    return {
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.ITEM),  -- 指定类型为物品
        user_id = params.user_id,
        item_id = params.item_id,
        bag_type = params.bag_type,
        slot_index = params.slot_index,
        count = params.count or 1,
        state = params.state or enum.ItemState.ITEM_STATE_NORMAL,  -- 确保默认状态为正常
        trade_state = params.trade_state or enum.TradeState.NONE,  -- 默认无交易
        auction_state = params.auction_state or enum.AuctionState.NONE,  -- 默认未拍卖
        
        -- 使用限制
        use_limit_type = params.use_limit_type or enum.UseLimitType.NONE,  -- 使用限制类型
        use_limit_count = params.use_limit_count,  -- 使用限制次数
        used_count = params.used_count or 0,       -- 已使用次数
        last_use_time = params.last_use_time,      -- 最后使用时间
        
        -- 过期时间
        expire_time = params.expire_time,          -- 过期时间
        
        -- 时间相关
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 创建物品变化日志
function M.new_change_log(params)
    return {
        user_id = params.user_id,
        item_id = params.item_id,
        count = params.count,
        type = params.type,                -- CHANGE_TYPE
        source = params.source,            -- CHANGE_SOURCE
        before_count = params.before_count,
        after_count = params.after_count,
        time = params.time or os.time()
    }
end

-- 验证物品数据
function M.validate(item_data)
    if not item_data then
        return false, "item data is empty"
    end
    
    if not item_data.user_id then
        return false, "user id is empty"
    end
    
    if not item_data.item_id then
        return false, "item id is empty"
    end
    
    if not item_data.count or item_data.count <= 0 then
        return false, "item count must be greater than 0"
    end
    
    return true
end

-- 检查物品是否过期
function M.is_expired(item)
    -- 1. 检查过期时间
    if item.expire_time and os.time() >= item.expire_time then
        return true
    end
    
    -- 2. 检查使用限制
    if item.use_limit_type == enum.UseLimitType.TOTAL and 
        item.used_count >= item.use_limit_count then
        return true
    end
    
    return false
end

-- 获取物品剩余时间(秒)
function M.get_remain_time(item)
    if not item.expire_time then
        return -1  -- 永不过期
    end
    
    local remain = item.expire_time - os.time()
    return math.max(0, remain)
end

-- 获取物品剩余使用次数
function M.get_remain_use_count(item)
    if item.use_limit_type == enum.UseLimitType.NONE then
        return -1  -- 无限制
    end
    
    return math.max(0, (item.use_limit_count or 0) - (item.used_count or 0))
end

return M 