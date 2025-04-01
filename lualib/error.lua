-- Generating error.lua from proto/common/error.proto
-- Generate time: 2025-04-01 03:06:18

local M = {}

-- 错误码定义
M.ErrorCode = {
    ERROR_CODE_SUCCESS = 0,    -- 成功
    ERROR_CODE_SYSTEM_ERROR = 1,    -- 系统错误
    ERROR_CODE_INVALID_PARAM = 2,    -- 无效参数
    ERROR_CODE_SERVER_BUSY = 9,    -- 服务器繁忙
    ERROR_CODE_VERSION_MISMATCH = 10,    -- 版本不匹配
    ERROR_CODE_DB_ERROR = 12,    -- 数据库错误
    ERROR_CODE_INVALID_ACCOUNT = 100,    -- 无效账号
    ERROR_CODE_WRONG_PASSWORD = 101,    -- 密码错误
    ERROR_CODE_ACCOUNT_EXISTS = 102,    -- 账号已存在
    ERROR_CODE_ACCOUNT_NOT_EXIST = 103,    -- 账号不存在
    ERROR_CODE_TOKEN_INVALID = 104,    -- 无效的令牌
    ERROR_CODE_TOKEN_EXPIRED = 105,    -- 令牌已过期
    ERROR_CODE_GATE_NOT_AVAILABLE = 106,    -- 网关不可用
    ERROR_CODE_ITEM_NOT_FOUND = 200,    -- 物品不存在
    ERROR_CODE_ITEM_NOT_ENOUGH = 201,    -- 物品数量不足
    ERROR_CODE_BAG_NOT_EXIST = 202,    -- 背包不存在
    ERROR_CODE_BAG_MAX_SIZE_LIMIT = 203,    -- 超过背包最大容量限制
    ERROR_CODE_BAG_EXPAND_FAILED = 204,    -- 扩展背包失败
    ERROR_CODE_INVALID_BAG_TYPE = 205,    -- 无效的背包类型
    ERROR_CODE_INSUFFICIENT_SPACE = 206,    -- 背包空间不足
    ERROR_CODE_INVALID_SLOT = 207,    -- 无效的格子
    ERROR_CODE_SLOT_LOCKED = 208,    -- 格子被锁定
    ERROR_CODE_ITEM_EFFECT_FAILED = 209,    -- 物品效果失败
    ERROR_CODE_GM_COMMAND_FAILED = 300,    -- GM指令执行失败
    ERROR_CODE_PERMISSION_DENIED = 301,    -- 权限不足
    ERROR_CODE_CARD_NOT_FOUND = 400,    -- 卡牌不存在
    ERROR_CODE_CARD_ALREADY_EXISTS = 401,    -- 卡牌已存在
    ERROR_CODE_CARD_NOT_ENOUGH = 402,    -- 卡牌数量不足
    ERROR_CODE_ITEM_NOT_EQUIPMENT = 500,    -- 物品不是装备
    ERROR_CODE_EQUIP_SLOT_NOT_MATCH = 501,    -- 装备槽位不匹配
    ERROR_CODE_LEVEL_NOT_ENOUGH = 502,    -- 等级不足
    ERROR_CODE_EQUIPMENT_NOT_FOUND = 503,    -- 装备不存在
    ERROR_CODE_TARGET_SLOT_OCCUPIED = 504,    -- 目标格子已被占用
    ERROR_PARTNER_NOT_FOUND = 600,    -- 伙伴不存在
    ERROR_PARTNER_NOT_OWNED = 601,    -- 伙伴不属于该用户
    ERROR_PARTNER_LEVEL_MAX = 602,    -- 伙伴等级已达上限
    ERROR_PARTNER_STAR_MAX = 603,    -- 伙伴星级已达上限
    ERROR_PARTNER_FRAGMENT_NOT_ENOUGH = 604,    -- 伙伴碎片不足
    ERROR_PARTNER_ALREADY_UNLOCKED = 605,    -- 伙伴已解锁
    ERROR_PARTNER_LEVEL_UP_ITEM_NOT_ENOUGH = 606,    -- 升级物品不足
    ERROR_PARTNER_STAR_UP_ITEM_NOT_ENOUGH = 607,    -- 升星物品不足
    ERROR_PARTNER_LEVEL_EXCEED_USER = 608,    -- 伙伴等级不能超过用户等级
}

-- error code description mapping
M.ErrorMessage = {
    [0] = "成功",
    [1] = "系统错误",
    [2] = "无效参数",
    [9] = "服务器繁忙",
    [10] = "版本不匹配",
    [12] = "数据库错误",
    [100] = "无效账号",
    [101] = "密码错误",
    [102] = "账号已存在",
    [103] = "账号不存在",
    [104] = "无效的令牌",
    [105] = "令牌已过期",
    [106] = "网关不可用",
    [200] = "物品不存在",
    [201] = "物品数量不足",
    [202] = "背包不存在",
    [203] = "超过背包最大容量限制",
    [204] = "扩展背包失败",
    [205] = "无效的背包类型",
    [206] = "背包空间不足",
    [207] = "无效的格子",
    [208] = "格子被锁定",
    [209] = "物品效果失败",
    [300] = "GM指令执行失败",
    [301] = "权限不足",
    [400] = "卡牌不存在",
    [401] = "卡牌已存在",
    [402] = "卡牌数量不足",
    [500] = "物品不是装备",
    [501] = "装备槽位不匹配",
    [502] = "等级不足",
    [503] = "装备不存在",
    [504] = "目标格子已被占用",
    [600] = "伙伴不存在",
    [601] = "伙伴不属于该用户",
    [602] = "伙伴等级已达上限",
    [603] = "伙伴星级已达上限",
    [604] = "伙伴碎片不足",
    [605] = "伙伴已解锁",
    [606] = "升级物品不足",
    [607] = "升星物品不足",
    [608] = "伙伴等级不能超过用户等级",
}

return M