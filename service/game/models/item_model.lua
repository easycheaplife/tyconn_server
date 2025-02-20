-- 物品数据模型定义
local M = {}

-- 物品变化类型
M.CHANGE_TYPE = {
    ADD = 1,    -- 增加
    REDUCE = 2, -- 减少
    USE = 3,    -- 使用
}

-- 物品变化来源
M.CHANGE_SOURCE = {
    INIT = "init",       -- 初始化
    REWARD = "reward",   -- 奖励
    USE = "use",        -- 使用
}

-- 物品效果类型
M.EFFECT_TYPE = {
    EXP = 1,    -- 经验
    GOLD = 2,   -- 金币
}

-- 物品类型
M.ITEM_TYPE = {
    CURRENCY = 1,    -- 货币类
    MATERIAL = 2,    -- 材料类
    EQUIPMENT = 3,   -- 装备类
    CONSUME = 4,     -- 消耗品
    GIFT = 5,        -- 礼包
    FRAGMENT = 6     -- 碎片
}

-- 绑定类型
M.BIND_TYPE = {
    NONE = 0,       -- 未绑定
    BIND = 1,       -- 已绑定
}

-- 创建新物品模型
function M.new(params)
    local now = os.time()
    return {
        -- 基础信息
        id = params.id,                    -- 物品实例ID
        user_id = params.user_id,          -- 所属用户ID
        item_id = params.item_id,          -- 物品模板ID
        count = params.count or 1,         -- 数量
        
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
        return false, "物品数据为空"
    end
    
    if not item_data.user_id then
        return false, "用户ID不能为空"
    end
    
    if not item_data.item_id then
        return false, "物品ID不能为空"
    end
    
    if not item_data.count or item_data.count <= 0 then
        return false, "物品数量必须大于0"
    end
    
    return true
end

-- 检查物品是否过期
function M.is_expired(item)
    if not item.expire_time then
        return false
    end
    return os.time() >= item.expire_time
end

return M 