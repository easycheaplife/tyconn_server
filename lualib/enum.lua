-- Generating enum.lua from proto/common/enum.proto
-- Generate time: 2025-04-22 03:34:43

local M = {}

M.UnitType = {
    UNIT_TYPE_HERO = 0,
    UNIT_TYPE_NPC = 1,
    UNIT_TYPE_MONSTER = 2,
    UNIT_TYPE_PARTNER = 4,
}

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
    SOURCE_CREATE = 2,    -- 创建
    SOURCE_USE = 3,    -- 使用
    SOURCE_CONSUME = 4,    -- 消耗
    SOURCE_BATCH_REMOVE = 5,    -- 批量删除
    SOURCE_LOCK = 6,    -- 锁定
    SOURCE_UNLOCK = 7,    -- 解锁
    SOURCE_RANDOM = 8,    -- 随机获得
    SOURCE_STACK = 11,    -- 堆叠
    SOURCE_TRADE = 12,    -- 交易
    SOURCE_MAIL = 13,    -- 邮件
    SOURCE_GM = 14,    -- GM命令
    SOURCE_MOVE = 15,    -- 物品移动
    SOURCE_SPLIT = 16,    -- 物品拆分
    SOURCE_CLEAR_BAG = 17,    -- 清空背包
    SOURCE_EQUIP = 21,    -- 装备
    SOURCE_UNEQUIP = 22,    -- 卸下装备
    SOURCE_ENHANCE = 23,    -- 强化
    SOURCE_REFINE = 24,    -- 精炼
    SOURCE_REFORGE = 25,    -- 洗练
    SOURCE_INLAY = 31,    -- 镶嵌宝石
    SOURCE_INLAY_BREAK = 32,    -- 宝石破碎
    SOURCE_REMOVE_GEM = 33,    -- 卸下宝石
    SOURCE_COMPOSE = 41,    -- 合成
    SOURCE_DECOMPOSE = 42,    -- 分解
    SOURCE_PARTNER_STAR_UP = 51,    -- 伙伴升星
    SOURCE_PARTNER_LEVEL_UP = 52,    -- 伙伴升级
    SOURCE_UNLOCK_PARTNER = 53,    -- 解锁伙伴
    SOURCE_REWARD = 61,    -- 奖励
    SOURCE_QUEST = 62,    -- 任务奖励
    SOURCE_ACTIVITY = 63,    -- 活动奖励
    SOURCE_ACHIEVEMENT = 64,    -- 成就奖励
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

-- 通用属性类型 (用于玩家、伙伴等所有实体)
M.PropType = {
    PROP_UNKNOWN = 0,
    PROP_MP = 101,    -- 魔法值
    PROP_HP = 102,    -- 生命值
    PROP_ATTACK = 103,    -- 攻击力
    PROP_DEFENSE = 104,    -- 防御力
    PROP_SPEED = 105,    -- 速度
    PROP_HIT = 201,    -- 命中率
    PROP_DODGE = 202,    -- 闪避率
    PROP_CRIT_RATE = 203,    -- 暴击率
    PROP_CRIT_DMG = 204,    -- 暴击伤害
    PROP_BLOCK = 205,    -- 格挡率
    PROP_PENETRATION = 206,    -- 穿透力
    PROP_HEAL_BOOST = 301,    -- 治疗加成
    PROP_DMG_BOOST = 302,    -- 伤害加成
    PROP_DMG_REDUCTION = 303,    -- 伤害减免
    PROP_EXP_BOOST = 304,    -- 经验加成
    PROP_FIRE_RES = 401,    -- 火焰抗性
    PROP_ICE_RES = 402,    -- 冰霜抗性
    PROP_LIGHTNING_RES = 403,    -- 雷电抗性
    PROP_POISON_RES = 404,    -- 毒素抗性
    PROP_GOLD_BOOST = 501,    -- 金币获取加成
    PROP_ITEM_FIND = 502,    -- 物品发现率
    PROP_MOVEMENT_SPEED = 503,    -- 移动速度
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
    EQUIP_SLOT_TYPE_WEAPON = 1,    -- 武器
    EQUIP_SLOT_TYPE_HAT = 2,    -- 帽子
    EQUIP_SLOT_TYPE_CLOTHES = 3,    -- 衣服
    EQUIP_SLOT_TYPE_TROUSERS = 4,    -- 裤子
    EQUIP_SLOT_TYPE_GLOVE = 5,    -- 手套
    EQUIP_SLOT_TYPE_BELT = 6,    -- 腰带
    EQUIP_SLOT_TYPE_SHOE = 7,    -- 鞋子
    EQUIP_SLOT_TYPE_CLOAK = 8,    -- 披风
    EQUIP_SLOT_TYPE_NECKLACE = 9,    -- 项链
    EQUIP_SLOT_TYPE_PENDANT = 10,    -- 玉佩
    EQUIP_SLOT_TYPE_BRACELET = 11,    -- 手镯
    EQUIP_SLOT_TYPE_RING = 12,    -- 戒指
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

-- 伙伴状态
M.PartnerState = {
    PARTNER_STATE_NONE = 0,
    PARTNER_STATE_AVAILABLE = 1,    -- 可解锁
    PARTNER_STATE_UNLOCKED = 2,    -- 已解锁
    PARTNER_STATE_LOCKED = 3,    -- 未解锁
}

-- 伙伴种族
M.PartnerRace = {
    PARTNER_RACE_NONE = 0,
    PARTNER_RACE_HUMAN = 1,    -- 人类
    PARTNER_RACE_ELF = 2,    -- 精灵
    PARTNER_RACE_DWARF = 3,    -- 矮人
    PARTNER_RACE_ORC = 4,    -- 兽人
    PARTNER_RACE_UNDEAD = 5,    -- 亡灵
    PARTNER_RACE_TAUREN = 6,    -- 牛头人
    PARTNER_RACE_GNOME = 7,    -- 侏儒
    PARTNER_RACE_TROLL = 8,    -- 巨魔
}

-- 伙伴特长/职业
M.PartnerForte = {
    PARTNER_FORTE_NONE = 0,
    PARTNER_FORTE_WARRIOR = 1,    -- 战士
    PARTNER_FORTE_MAGE = 2,    -- 法师
    PARTNER_FORTE_PRIEST = 3,    -- 牧师
    PARTNER_FORTE_ROGUE = 4,    -- 盗贼
    PARTNER_FORTE_HUNTER = 5,    -- 猎人
    PARTNER_FORTE_PALADIN = 6,    -- 圣骑士
    PARTNER_FORTE_SHAMAN = 7,    -- 萨满
    PARTNER_FORTE_DRUID = 8,    -- 德鲁伊
    PARTNER_FORTE_WARLOCK = 9,    -- 术士
}

-- 格子类型
M.CellType = {
    CELL_TYPE_NONE = 0,    -- 未知类型
    CELL_TYPE_START = 1,    -- 起点
    CELL_TYPE_NORMAL = 2,    -- 普通格子
    CELL_TYPE_CHANCE = 3,    -- 机会格子
    CELL_TYPE_TREASURE = 4,    -- 宝藏格子
    CELL_TYPE_TRAP = 5,    -- 陷阱格子
    CELL_TYPE_SHOP = 6,    -- 商店格子
    CELL_TYPE_REST = 7,    -- 休息格子
    CELL_TYPE_TELEPORT = 8,    -- 传送格子
    CELL_TYPE_BATTLE = 9,    -- 战斗格子
    CELL_TYPE_PROPERTY = 10,    -- 地产格子
    CELL_TYPE_CHECKPOINT = 11,    -- 检查点
    CELL_TYPE_BOSS = 12,    -- Boss格子
    CELL_TYPE_MYSTERY = 13,    -- 神秘格子
}

-- 格子事件类型
M.CellEventType = {
    EVENT_TYPE_NONE = 0,    -- 未知事件
    EVENT_TYPE_START = 101,    -- 起点
    EVENT_TYPE_END = 102,    -- 终点
    EVENT_TYPE_TURN = 103,    -- 转向
    EVENT_TYPE_JUMP = 104,    -- 跳跃至格子ID
    EVENT_TYPE_BATTLE = 200,    -- 触发战斗
    EVENT_TYPE_TASK = 201,    -- 触发任务
    EVENT_TYPE_ITEM_REWARD = 400,    -- 物品奖励
    EVENT_TYPE_ITEM_EQUIP_REWARD = 410,    -- 物品奖励-装备
    EVENT_TYPE_NPC_SHOP = 501,    -- NPC商店
    EVENT_TYPE_WHEEL_SHOP = 502,    -- 轮盘商店
    EVENT_TYPE_MODIFY_ATTR = 503,    -- 修改大富翁属性
    EVENT_TYPE_MODIFY_BATTLE = 504,    -- 修改战斗属性
    EVENT_TYPE_ADD_SCENE_BUFF = 505,    -- 添加场景BUFF
    EVENT_TYPE_ADD_TRIGGER_BUFF = 506,    -- 添加触发者BUFF
    EVENT_TYPE_ADD_PLAYER_BUFF = 507,    -- 添加玩主角BUFF
    EVENT_TYPE_RANDOM_EVENT = 900,    -- 随机事件
}

-- 章节通关条件类型
M.ChapterConditionType = {
    CONDITION_TYPE_NONE = 0,    -- 未知条件
    CONDITION_TYPE_REACH_END = 1,    -- 到达终点
    CONDITION_TYPE_PLAYER_LEVEL = 2,    -- 玩家等级达到
    CONDITION_TYPE_PASS_STAGES = 3,    -- 通过指定关卡数
}

-- 事件触发方式
M.CellEventActivateType = {
    ACTIVATE_TYPE_NONE = 0,
    ACTIVATE_TYPE_LAND = 1,    -- 踩中
    ACTIVATE_TYPE_PASS = 2,    -- 路过/经过
}

-- 随机事件格子互斥类型
M.MutexType = {
    MUTEX_TYPE_EXCLUSIVE = 0,    -- 互斥：只随机没有事件的格子
    MUTEX_TYPE_REPLACE = 1,    -- 替换：替换已有的事件
    MUTEX_TYPE_NO_LIMIT = 2,    -- 无限制：不做任何限制
}

return M