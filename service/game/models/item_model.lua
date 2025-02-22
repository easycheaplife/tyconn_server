local snowflake = require "utils.snowflake"

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
    COMPOSE = "compose", -- 合成
    DECOMPOSE = "decompose", -- 分解
    LOCK = "lock",      -- 锁定
    UNLOCK = "unlock",   -- 解锁
    STACK = "stack",     -- 堆叠
    SPLIT = "split"      -- 拆分
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

-- 物品标签
M.ITEM_TAG = {
    QUEST = "quest",         -- 任务物品
    RARE = "rare",          -- 稀有物品
    TRADABLE = "tradable",  -- 可交易
    BIND = "bind",          -- 绑定物品
    EXPIRE = "expire",      -- 限时物品
    STACK = "stack",        -- 可堆叠
    UNIQUE = "unique"       -- 唯一物品
}

-- 物品分类
M.ITEM_CATEGORY = {
    WEAPON = 1,      -- 武器
    ARMOR = 2,       -- 防具
    ACCESSORY = 3,   -- 饰品
    POTION = 4,      -- 药水
    SCROLL = 5,      -- 卷轴
    MATERIAL = 6,    -- 材料
    QUEST = 7,       -- 任务
    OTHER = 8        -- 其他
}

-- 绑定类型
M.BIND_TYPE = {
    NONE = 0,       -- 未绑定
    BIND = 1,       -- 已绑定
}

-- 背包类型
M.BAG_TYPE = {
    MAIN = 1,      -- 主背包
    STORAGE = 2,   -- 仓库
    EQUIP = 3,     -- 装备栏
}

-- 背包格子状态
M.SLOT_STATE = {
    EMPTY = 0,     -- 空格子
    OCCUPIED = 1,  -- 已占用
    LOCKED = 2,    -- 已锁定
}

-- 合成结果类型
M.COMPOSE_RESULT = {
    SUCCESS = 1,     -- 成功
    FAIL = 2,       -- 失败但不消耗材料
    FAIL_CONSUME = 3 -- 失败且消耗材料
}

-- 分解结果类型
M.DECOMPOSE_RESULT = {
    NORMAL = 1,    -- 普通产出
    EXTRA = 2,     -- 额外产出
    CRITICAL = 3   -- 暴击产出
}

-- 使用限制类型
M.USE_LIMIT_TYPE = {
    NONE = 0,        -- 无限制
    DAILY = 1,       -- 每日限制
    WEEKLY = 2,      -- 每周限制
    TOTAL = 3        -- 总次数限制
}

-- 装备槽位
M.EQUIP_SLOT = {
    WEAPON = 1,      -- 武器槽
    HEAD = 2,        -- 头部槽
    BODY = 3,        -- 身体槽
    HANDS = 4,       -- 手部槽
    FEET = 5,        -- 脚部槽
    NECK = 6,        -- 项链槽
    FINGER1 = 7,     -- 戒指槽1
    FINGER2 = 8,     -- 戒指槽2
    TRINKET = 9      -- 饰品槽
}

-- 装备属性类型
M.EQUIP_PROP = {
    ATK = "atk",           -- 攻击力
    DEF = "def",           -- 防御力
    HP = "hp",             -- 生命值
    MP = "mp",             -- 魔法值
    CRIT_RATE = "crit",    -- 暴击率
    CRIT_DMG = "crit_dmg", -- 暴击伤害
    SPEED = "speed",       -- 速度
    DODGE = "dodge"        -- 闪避率
}

-- 强化结果类型
M.ENHANCE_RESULT = {
    SUCCESS = 1,     -- 成功
    FAIL = 2,       -- 失败但不降级
    FAIL_DOWN = 3,  -- 失败且降级
    BREAK = 4       -- 失败且装备破碎
}

-- 强化属性类型
M.ENHANCE_TYPE = {
    NORMAL = 1,     -- 普通强化
    PERFECT = 2,    -- 完美强化
    LUCKY = 3       -- 幸运强化
}

-- 精炼结果类型
M.REFINE_RESULT = {
    SUCCESS = 1,     -- 成功
    FAIL = 2,       -- 失败但不降级
    FAIL_DOWN = 3,  -- 失败且降级
    BREAK = 4       -- 失败且装备破碎
}

-- 洗练属性类型
M.REFORGE_PROP = {
    FIXED = 1,      -- 固定属性
    RANDOM = 2,     -- 随机属性
    SPECIAL = 3     -- 特殊属性
}

-- 洗练结果类型
M.REFORGE_RESULT = {
    SUCCESS = 1,    -- 成功
    FAIL = 2,      -- 失败
    PERFECT = 3    -- 完美洗练
}

-- 宝石类型
M.GEM_TYPE = {
    ATTACK = 1,     -- 攻击宝石
    DEFENSE = 2,    -- 防御宝石
    HEALTH = 3,     -- 生命宝石
    CRIT = 4,       -- 暴击宝石
    SPEED = 5,      -- 速度宝石
    SPECIAL = 6     -- 特殊宝石
}

-- 宝石槽位状态
M.GEM_SLOT_STATE = {
    EMPTY = 0,      -- 空槽位
    OCCUPIED = 1,   -- 已镶嵌
    LOCKED = 2      -- 已锁定
}

-- 宝石操作结果
M.GEM_RESULT = {
    SUCCESS = 1,    -- 成功
    FAIL = 2,      -- 失败
    BREAK = 3      -- 宝石破碎
}

-- 物品状态
M.ITEM_STATE = {
    NORMAL = 0,     -- 正常
    LOCKED = 1,     -- 锁定
    TRADING = 2,    -- 交易中
    AUCTIONING = 3, -- 拍卖中
}

-- 交易状态
M.TRADE_STATE = {
    NONE = 0,       -- 无交易
    PENDING = 1,    -- 等待交易
    TRADING = 2,    -- 交易中
    COMPLETED = 3,  -- 交易完成
}

-- 拍卖状态
M.AUCTION_STATE = {
    NONE = 0,       -- 未拍卖
    ONGOING = 1,    -- 拍卖中
    COMPLETED = 2,  -- 已成交
    CANCELLED = 3,  -- 已取消
}

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
        state = params.state or M.ITEM_STATE.NORMAL,  -- 默认正常状态
        trade_state = params.trade_state or M.TRADE_STATE.NONE,  -- 默认无交易
        auction_state = params.auction_state or M.AUCTION_STATE.NONE,  -- 默认未拍卖
        
        -- 使用限制
        use_limit_type = params.use_limit_type or M.USE_LIMIT_TYPE.NONE,  -- 使用限制类型
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
    -- 1. 检查过期时间
    if item.expire_time and os.time() >= item.expire_time then
        return true
    end
    
    -- 2. 检查使用限制
    if item.use_limit_type == M.USE_LIMIT_TYPE.TOTAL and 
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
    if item.use_limit_type == M.USE_LIMIT_TYPE.NONE then
        return -1  -- 无限制
    end
    
    return math.max(0, (item.use_limit_count or 0) - (item.used_count or 0))
end

return M 