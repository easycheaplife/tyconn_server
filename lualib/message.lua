-- Generating message.lua from proto/common/message.proto
-- Generate time: 2025-04-01 03:06:18

local M = {}

-- 消息ID定义
M.MessageID = {
    NONE = 0,
    C2L_LOGIN_REQUEST = 1,    -- 客户端到登录服务器的登录请求
    L2C_LOGIN_RESPONSE = 2,    -- 登录服务器到客户端的登录响应
    C2G_HEARTBEAT_REQUEST = 3,    -- 客户端到游戏服务器的心跳请求
    G2C_HEARTBEAT_RESPONSE = 4,    -- 游戏服务器到客户端的心跳响应
    C2G_USER_INFO_REQUEST = 5,    -- 获取用户信息请求
    G2C_USER_INFO_RESPONSE = 6,    -- 获取用户信息响应
    C2G_LOGIN_GAME_REQUEST = 7,    -- 客户端到游戏服务器的登录请求
    G2C_LOGIN_GAME_RESPONSE = 8,    -- 游戏服务器到客户端的登录响应
    C2G_USER_CARDS_REQUEST = 101,    -- 获取用户卡牌请求
    G2C_USER_CARDS_RESPONSE = 102,    -- 获取用户卡牌响应
    C2G_BAG_INFO_REQUEST = 201,    -- 获取背包信息请求
    G2C_BAG_INFO_RESPONSE = 202,    -- 获取背包信息响应
    C2G_USE_ITEM_REQUEST = 203,    -- 使用物品请求
    G2C_USE_ITEM_RESPONSE = 204,    -- 使用物品响应
    C2G_EXPAND_BAG_REQUEST = 205,    -- 扩展背包请求
    G2C_EXPAND_BAG_RESPONSE = 206,    -- 扩展背包响应
    C2G_SORT_BAG_REQUEST = 207,    -- 整理背包请求
    G2C_SORT_BAG_RESPONSE = 208,    -- 整理背包响应
    C2G_MOVE_ITEM_REQUEST = 209,    -- 移动物品请求
    G2C_MOVE_ITEM_RESPONSE = 210,    -- 移动物品响应
    C2G_COMPOSE_ITEM_REQUEST = 211,    -- 物品合成请求
    G2C_COMPOSE_ITEM_RESPONSE = 212,    -- 物品合成响应
    C2G_DECOMPOSE_ITEM_REQUEST = 213,    -- 物品分解请求
    G2C_DECOMPOSE_ITEM_RESPONSE = 214,    -- 物品分解响应
    C2G_GM_COMMAND_REQUEST = 301,    -- GM命令请求
    G2C_GM_COMMAND_RESPONSE = 302,    -- GM命令响应
    C2G_EQUIP_INFO_REQUEST = 401,    -- 获取装备信息请求
    G2C_EQUIP_INFO_RESPONSE = 402,    -- 获取装备信息响应
    C2G_EQUIP_ITEM_REQUEST = 403,    -- 装备物品请求
    G2C_EQUIP_ITEM_RESPONSE = 404,    -- 装备物品响应
    C2G_UNEQUIP_ITEM_REQUEST = 405,    -- 卸下装备请求
    G2C_UNEQUIP_ITEM_RESPONSE = 406,    -- 卸下装备响应
    C2G_EQUIP_RANDOM_REQUEST = 407,    -- 随机装备请求
    G2C_EQUIP_RANDOM_RESPONSE = 408,    -- 随机装备响应
    C2G_EQUIP_LEVEL_INFO_REQUEST = 409,    -- 获取装备等级信息请求
    G2C_EQUIP_LEVEL_INFO_RESPONSE = 410,    -- 获取装备等级信息响应
    C2G_EQUIP_LEVEL_UPGRADE_REQUEST = 411,    -- 装备等级升级请求
    G2C_EQUIP_LEVEL_UPGRADE_RESPONSE = 412,    -- 装备等级升级响应
    G2C_EQUIPMENT_EXPIRED_PUSH = 451,    -- 装备过期推送
    G2C_EQUIPMENT_LEVEL_UPGRADED_PUSH = 452,    -- 装备等级升级完成推送
    C2G_MAIL_LIST_REQUEST = 501,    -- 获取邮件列表请求
    G2C_MAIL_LIST_RESPONSE = 502,    -- 获取邮件列表响应
    C2G_READ_MAIL_REQUEST = 503,    -- 读取邮件请求
    G2C_READ_MAIL_RESPONSE = 504,    -- 读取邮件响应
    C2G_CLAIM_MAIL_ITEMS_REQUEST = 505,    -- 领取邮件附件请求
    G2C_CLAIM_MAIL_ITEMS_RESPONSE = 506,    -- 领取邮件附件响应
    C2G_DELETE_MAIL_REQUEST = 507,    -- 删除邮件请求
    G2C_DELETE_MAIL_RESPONSE = 508,    -- 删除邮件响应
    G2C_NEW_MAIL_PUSH = 551,    -- 新邮件推送
    C2G_PARTNER_LIST_REQUEST = 601,    -- 获取伙伴列表请求
    G2C_PARTNER_LIST_RESPONSE = 602,    -- 获取伙伴列表响应
    C2G_PARTNER_LEVEL_UP_REQUEST = 603,    -- 伙伴升级请求
    G2C_PARTNER_LEVEL_UP_RESPONSE = 604,    -- 伙伴升级响应
    C2G_PARTNER_STAR_UP_REQUEST = 605,    -- 伙伴升星请求
    G2C_PARTNER_STAR_UP_RESPONSE = 606,    -- 伙伴升星响应
    C2G_PARTNER_UNLOCK_REQUEST = 607,    -- 伙伴解锁请求
    G2C_PARTNER_UNLOCK_RESPONSE = 608,    -- 伙伴解锁响应
    G2C_PARTNER_PROPERTY_CHANGED_PUSH = 651,    -- 伙伴属性变化推送
    C2G_MAP_INFO_REQUEST = 701,    -- 获取地图信息请求
    G2C_MAP_INFO_RESPONSE = 702,    -- 获取地图信息响应
    C2G_ROLL_DICE_REQUEST = 703,    -- 掷骰子请求
    G2C_ROLL_DICE_RESPONSE = 704,    -- 掷骰子响应
    C2G_HANDLE_CELL_EVENT_REQUEST = 705,    -- 处理格子事件请求
    G2C_HANDLE_CELL_EVENT_RESPONSE = 706,    -- 处理格子事件响应
    C2G_CLAIM_REWARD_REQUEST = 707,    -- 领取通关奖励请求
    G2C_CLAIM_REWARD_RESPONSE = 718,    -- 领取通关奖励响应
    G2C_CHAPTER_COMPLETED_PUSH = 751,    -- 章节完成推送
}

return M