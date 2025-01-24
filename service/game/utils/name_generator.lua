local M = {}

-- 前缀词库
local PREFIXES = {
    -- 元素
    "火", "冰", "风", "雷", "光", "暗", "星", "月",
    -- 品质
    "神", "圣", "魔", "幻", "龙", "凤", "天", "地",
    -- 状态
    "醉", "狂", "傲", "血", "影", "梦", "夜", "霜",
    -- 气质
    "剑", "刀", "枪", "弓", "战", "武", "侠", "仙"
}

-- 中缀词库
local MIDDLES = {
    -- 动作
    "舞", "啸", "击", "破", "斩", "御", "追", "逐",
    -- 状态
    "狱", "魂", "心", "命", "灵", "意", "神", "魄",
    -- 场景
    "天", "地", "山", "海", "云", "月", "星", "空"
}

-- 后缀词库
local SUFFIXES = {
    -- 称号
    "王", "尊", "帝", "圣", "主", "君", "神", "仙",
    -- 职业
    "士", "者", "手", "师", "客", "侠", "将", "兵",
    -- 物品
    "剑", "刃", "刀", "枪", "弓", "戟", "印", "玉"
}

-- 生成随机用户名
function M.generate_username()
    -- 随机决定用户名长度(2-3个词)
    local name_parts = {}
    local length = math.random(2, 3)
    
    if length == 2 then
        -- 两字结构：前缀 + 后缀
        name_parts[1] = PREFIXES[math.random(1, #PREFIXES)]
        name_parts[2] = SUFFIXES[math.random(1, #SUFFIXES)]
    else
        -- 三字结构：前缀 + 中缀 + 后缀
        name_parts[1] = PREFIXES[math.random(1, #PREFIXES)]
        name_parts[2] = MIDDLES[math.random(1, #MIDDLES)]
        name_parts[3] = SUFFIXES[math.random(1, #SUFFIXES)]
    end
    
    -- 添加随机数以确保唯一性
    local name = table.concat(name_parts)
    return name .. string.format("%03d", math.random(1, 999))
end

-- 示例生成的名字：
-- 剑破王123  (2字结构)
-- 火舞剑456  (3字结构)
-- 神魂帝789  (3字结构)
-- 冰天仙234  (3字结构)
-- 战灵侠567  (3字结构)

return M 