-- using proto/common/enum.proto to generate enum.lua
-- generate time: 2025-03-10 10:12:00

local M = {}

-- 背包类型
M.BagType = {
    BAG_TYPE_NONE = 0,
    BAG_TYPE_MAIN = 1,    -- 主背包
    BAG_TYPE_STORAGE = 2,    -- 仓库
    BAG_TYPE_EQUIP = 3,    -- 装备栏
}

-- 物品类型
M.ItemType = {
    ITEM_TYPE_NONE = 0,
    ITEM_TYPE_RESOURCE = 1,    -- 资源
    ITEM_TYPE_NORMAL = 2,    -- 普通
    ITEM_TYPE_EQUIP = 3,    -- 装备
    ITEM_TYPE_PARTNER = 4,    -- 伙伴
    ITEM_TYPE_PARTNER_FRAGMENT = 5,    -- 伙伴碎片
    ITEM_TYPE_TREASURE = 9,    -- 宝箱
}

-- 物品分类
M.ItemCategory = {
    ITEM_CATEGORY_NONE = 0,
    ITEM_CATEGORY_WEAPON = 1,    -- 武器
    ITEM_CATEGORY_ARMOR = 2,    -- 防具
    ITEM_CATEGORY_ACCESSORY = 3,    -- 饰品
    ITEM_CATEGORY_POTION = 4,    -- 药水
    ITEM_CATEGORY_SCROLL = 5,    -- 卷轴
    ITEM_CATEGORY_MATERIAL = 6,    -- 材料
    ITEM_CATEGORY_QUEST = 7,    -- 任务
    ITEM_CATEGORY_OTHER = 8,    -- 其他
}

M.SpecialItemID = {
    SPECIAL_ITEM_ID_NONE = 0,
    SPECIAL_ITEM_ID_GOLD = 1001,    -- 金币
    SPECIAL_ITEM_ID_EXP = 1005,    -- 经验
}

-- 格子状态
M.SlotState = {
    SLOT_STATE_NONE = 0,
    SLOT_STATE_EMPTY = 1,    -- 空格子
    SLOT_STATE_NORMAL = 2,    -- 正常
    SLOT_STATE_LOCKED = 3,    -- 锁定
}

-- 变化类型
M.ChangeType = {
    CHANGE_TYPE_NONE = 0,
    CHANGE_TYPE_ADD = 1,    -- 增加
    CHANGE_TYPE_REDUCE = 2,    -- 减少
    CHANGE_TYPE_USE = 3,    -- 使用
    CHANGE_TYPE_COMPOSE = 4,    -- 合成
    CHANGE_TYPE_DECOMPOSE = 5,    -- 分解
}

-- 变化来源
M.ChangeSource = {
    SOURCE_NONE = 0,
    SOURCE_INIT = 1,    -- 初始化
    SOURCE_REWARD = 2,    -- 奖励
    SOURCE_CREATE = 3,    -- 创建
    SOURCE_USE = 4,    -- 使用
    SOURCE_COMPOSE = 5,    -- 合成
    SOURCE_DECOMPOSE = 6,    -- 分解
    SOURCE_STACK = 7,    -- 堆叠
    SOURCE_BATCH_REMOVE = 8,    -- 批量删除
    SOURCE_TRADE = 9,    -- 交易
    SOURCE_MAIL = 10,    -- 邮件
    SOURCE_GM = 11,    -- GM
    SOURCE_REMOVE_GEM = 12,    -- 卸下宝石
    SOURCE_UNEQUIP = 13,    -- 卸下装备
    SOURCE_ENHANCE = 14,    -- 强化
    SOURCE_REFINE = 15,    -- 精炼
    SOURCE_REFORGE = 16,    -- 洗练
}

-- 效果类型
M.EffectType = {
    EFFECT_TYPE_NONE = 0,
    EFFECT_TYPE_EXP = 1,    -- 经验
    EFFECT_TYPE_GOLD = 2,    -- 金币
    EFFECT_TYPE_DIAMOND = 3,    -- 钻石
    EFFECT_TYPE_PROP = 4,    -- 属性
}

-- 品质
M.Quality = {
    QUALITY_NONE = 0,
    QUALITY_WHITE = 1,    -- 白色/普通
    QUALITY_GREEN = 2,    -- 绿色/优秀
    QUALITY_BLUE = 3,    -- 蓝色/精良
    QUALITY_PURPLE = 4,    -- 紫色/史诗
    QUALITY_ORANGE = 5,    -- 橙色/传说
    QUALITY_RED = 6,    -- 红色/神话
}

-- 排序规则
M.SortRule = {
    SORT_RULE_NONE = 0,
    SORT_RULE_TYPE = 1,    -- 按类型
    SORT_RULE_QUALITY = 2,    -- 按品质
    SORT_RULE_LEVEL = 3,    -- 按等级
    SORT_RULE_COUNT = 4,    -- 按数量
    SORT_RULE_TIME = 5,    -- 按时间
}

-- 使用限制类型
M.UseLimit = {
    USE_LIMIT_NONE = 0,
    USE_LIMIT_LEVEL = 1,    -- 等级限制
    USE_LIMIT_VIP = 2,    -- VIP等级限制
    USE_LIMIT_TIME = 3,    -- 时间限制
    USE_LIMIT_COUNT = 4,    -- 次数限制
    USE_LIMIT_DAILY = 5,    -- 每日限制
    USE_LIMIT_WEEKLY = 6,    -- 每周限制
}

-- 道具类型
M.PropType = {
    PROP_TYPE_NONE = 0,
    PROP_TYPE_HP = 1,    -- 生命值
    PROP_TYPE_ATTACK = 2,    -- 攻击力
    PROP_TYPE_DEFENSE = 3,    -- 防御力
    PROP_TYPE_SPEED = 4,    -- 速度
    PROP_TYPE_CRIT = 5,    -- 暴击
    PROP_TYPE_CRIT_DMG = 6,    -- 暴击伤害
}

-- 装备位置
M.EquipSlot = {
    EQUIP_SLOT_NONE = 0,
    EQUIP_SLOT_WEAPON = 1,    -- 武器
    EQUIP_SLOT_ARMOR = 2,    -- 护甲
    EQUIP_SLOT_HELMET = 3,    -- 头盔
    EQUIP_SLOT_NECKLACE = 4,    -- 项链
    EQUIP_SLOT_RING = 5,    -- 戒指
    EQUIP_SLOT_BELT = 6,    -- 腰带
}

-- 强化类型
M.EnhanceType = {
    ENHANCE_TYPE_NONE = 0,
    ENHANCE_TYPE_LEVEL = 1,    -- 等级强化
    ENHANCE_TYPE_STAR = 2,    -- 升星
    ENHANCE_TYPE_REFINE = 3,    -- 精炼
    ENHANCE_TYPE_REFORGE = 4,    -- 重铸
}

-- 物品标签
M.ItemTag = {
    ITEM_TAG_NONE = 0,
    ITEM_TAG_QUEST = 1,    -- 任务物品
    ITEM_TAG_RARE = 2,    -- 稀有物品
    ITEM_TAG_TRADABLE = 3,    -- 可交易
    ITEM_TAG_BIND = 4,    -- 绑定物品
    ITEM_TAG_EXPIRE = 5,    -- 限时物品
    ITEM_TAG_STACK = 6,    -- 可堆叠
    ITEM_TAG_UNIQUE = 7,    -- 唯一物品
}

-- 绑定类型
M.BindType = {
    BIND_TYPE_NONE = 0,    -- 未绑定
    BIND_TYPE_BIND = 1,    -- 已绑定
}

-- 合成结果类型
M.ComposeResult = {
    COMPOSE_RESULT_NONE = 0,
    COMPOSE_RESULT_SUCCESS = 1,    -- 成功
    COMPOSE_RESULT_FAIL = 2,    -- 失败但不消耗材料
    COMPOSE_RESULT_FAIL_CONSUME = 3,    -- 失败且消耗材料
}

-- 分解结果类型
M.DecomposeResult = {
    DECOMPOSE_RESULT_NONE = 0,
    DECOMPOSE_RESULT_NORMAL = 1,    -- 普通产出
    DECOMPOSE_RESULT_EXTRA = 2,    -- 额外产出
    DECOMPOSE_RESULT_CRITICAL = 3,    -- 暴击产出
}

-- 使用限制类型
M.UseLimitType = {
    USE_LIMIT_TYPE_NONE = 0,    -- 无限制
    USE_LIMIT_TYPE_DAILY = 1,    -- 每日限制
    USE_LIMIT_TYPE_WEEKLY = 2,    -- 每周限制
    USE_LIMIT_TYPE_TOTAL = 3,    -- 总次数限制
}

-- 装备槽位
M.EquipSlotType = {
    EQUIP_SLOT_TYPE_NONE = 0,
    EQUIP_SLOT_TYPE_WEAPON = 1,    -- 武器槽
    EQUIP_SLOT_TYPE_HEAD = 2,    -- 头部槽
    EQUIP_SLOT_TYPE_BODY = 3,    -- 身体槽
    EQUIP_SLOT_TYPE_HANDS = 4,    -- 手部槽
    EQUIP_SLOT_TYPE_FEET = 5,    -- 脚部槽
    EQUIP_SLOT_TYPE_NECK = 6,    -- 项链槽
    EQUIP_SLOT_TYPE_TRINKET = 9,    -- 饰品槽
}

-- 装备属性类型
M.EquipPropType = {
    EQUIP_PROP_TYPE_NONE = 0,
    EQUIP_PROP_TYPE_ATK = 1,    -- 攻击力
    EQUIP_PROP_TYPE_DEF = 2,    -- 防御力
    EQUIP_PROP_TYPE_HP = 3,    -- 生命值
    EQUIP_PROP_TYPE_MP = 4,    -- 魔法值
    EQUIP_PROP_TYPE_CRIT_RATE = 5,    -- 暴击率
    EQUIP_PROP_TYPE_CRIT_DMG = 6,    -- 暴击伤害
    EQUIP_PROP_TYPE_SPEED = 7,    -- 速度
    EQUIP_PROP_TYPE_DODGE = 8,    -- 闪避率
}

-- 强化结果类型
M.EnhanceResult = {
    ENHANCE_RESULT_NONE = 0,
    ENHANCE_RESULT_SUCCESS = 1,    -- 成功
    ENHANCE_RESULT_FAIL = 2,    -- 失败但不降级
    ENHANCE_RESULT_FAIL_DOWN = 3,    -- 失败且降级
    ENHANCE_RESULT_BREAK = 4,    -- 失败且装备破碎
}

-- 精炼结果类型
M.RefineResult = {
    REFINE_RESULT_NONE = 0,
    REFINE_RESULT_SUCCESS = 1,    -- 成功
    REFINE_RESULT_FAIL = 2,    -- 失败但不降级
    REFINE_RESULT_FAIL_DOWN = 3,    -- 失败且降级
    REFINE_RESULT_BREAK = 4,    -- 失败且装备破碎
}

-- 洗练属性类型
M.ReforgePropType = {
    REFORGE_PROP_TYPE_NONE = 0,
    REFORGE_PROP_TYPE_FIXED = 1,    -- 固定属性
    REFORGE_PROP_TYPE_RANDOM = 2,    -- 随机属性
    REFORGE_PROP_TYPE_SPECIAL = 3,    -- 特殊属性
}

-- 洗练结果类型
M.ReforgeResult = {
    REFORGE_RESULT_NONE = 0,
    REFORGE_RESULT_SUCCESS = 1,    -- 成功
    REFORGE_RESULT_FAIL = 2,    -- 失败
    REFORGE_RESULT_PERFECT = 3,    -- 完美洗练
}

-- 宝石类型
M.GemType = {
    GEM_TYPE_NONE = 0,
    GEM_TYPE_ATTACK = 1,    -- 攻击宝石
    GEM_TYPE_DEFENSE = 2,    -- 防御宝石
    GEM_TYPE_HEALTH = 3,    -- 生命宝石
    GEM_TYPE_CRIT = 4,    -- 暴击宝石
    GEM_TYPE_SPEED = 5,    -- 速度宝石
    GEM_TYPE_SPECIAL = 6,    -- 特殊宝石
}

-- 宝石槽位状态
M.GemSlotState = {
    GEM_SLOT_STATE_NONE = 0,
    GEM_SLOT_STATE_EMPTY = 1,    -- 空槽位
    GEM_SLOT_STATE_OCCUPIED = 2,    -- 已镶嵌
    GEM_SLOT_STATE_LOCKED = 3,    -- 已锁定
}

-- 宝石操作结果
M.GemResult = {
    GEM_RESULT_NONE = 0,
    GEM_RESULT_SUCCESS = 1,    -- 成功
    GEM_RESULT_FAIL = 2,    -- 失败
    GEM_RESULT_BREAK = 3,    -- 宝石破碎
}

-- 物品状态
M.ItemState = {
    ITEM_STATE_NONE = 0,
    ITEM_STATE_NORMAL = 1,    -- 正常
    ITEM_STATE_LOCKED = 2,    -- 锁定
    ITEM_STATE_TRADING = 3,    -- 交易中
    ITEM_STATE_AUCTIONING = 4,    -- 拍卖中
}

-- 交易状态
M.TradeState = {
    TRADE_STATE_NONE = 0,
    TRADE_STATE_PENDING = 1,    -- 等待交易
    TRADE_STATE_TRADING = 2,    -- 交易中
    TRADE_STATE_COMPLETED = 3,    -- 交易完成
}

-- 拍卖状态
M.AuctionState = {
    AUCTION_STATE_NONE = 0,
    AUCTION_STATE_ONGOING = 1,    -- 拍卖中
    AUCTION_STATE_COMPLETED = 2,    -- 已成交
    AUCTION_STATE_CANCELLED = 3,    -- 已取消
}

-- 邮件类型
M.MailType = {
    MAIL_TYPE_NONE = 0,
    MAIL_TYPE_SYSTEM = 1,    -- 系统邮件
    MAIL_TYPE_PERSONAL = 2,    -- 个人邮件
}

-- 邮件状态
M.MailStatus = {
    MAIL_STATUS_NONE = 0,
    MAIL_STATUS_UNREAD = 1,    -- 未读
    MAIL_STATUS_READ = 2,    -- 已读
    MAIL_STATUS_CLAIMED = 3,    -- 已领取
    MAIL_STATUS_DELETED = 4,    -- 已删除
    MAIL_STATUS_EXPIRED = 5,    -- 已过期
}

-- 资源类型
M.ResourceType = {
    RESOURCE_TYPE_NONE = 0,
    RESOURCE_TYPE_GOLD = 1,    -- 金币
    RESOURCE_TYPE_EXP = 2,    -- 经验
}

return M