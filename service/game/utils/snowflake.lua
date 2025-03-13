local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 时间戳位数
local TIMESTAMP_BITS = 32  -- 减少时间戳位数，确保不会溢出

-- 类型位数
local TYPE_BITS = 5       -- 最多32种类型

-- 机器ID位数
local WORKER_BITS = 5     -- 最多32个节点

-- 序列号位数
local SEQUENCE_BITS = 10  -- 每毫秒1024个序号

-- 起始时间戳 (2024-01-01 00:00:00)
local EPOCH = 1704038400000  -- 使用毫秒级时间戳

-- 最大值
local MAX_SEQUENCE = (1 << SEQUENCE_BITS) - 1
local MAX_WORKER_ID = (1 << WORKER_BITS) - 1
local MAX_TYPE_ID = (1 << TYPE_BITS) - 1

-- 位移
local TIMESTAMP_SHIFT = TYPE_BITS + WORKER_BITS + SEQUENCE_BITS
local TYPE_SHIFT = WORKER_BITS + SEQUENCE_BITS
local WORKER_SHIFT = SEQUENCE_BITS

-- ID类型
M.ID_TYPE = {
    USER = 1,       -- 用户
    CARD = 2,       -- 卡牌
    ITEM = 3,       -- 物品
    BAG = 4,        -- 背包
    SLOT = 5,       -- 格子
    MAIL = 6,       -- 邮件
    TASK = 7,       -- 任务
    GUILD = 8,      -- 公会
    TRADE = 9,      -- 交易
    CHAT = 10,      -- 聊天
    PARTNER = 11,   -- 伙伴
}

-- 当前值
local worker_id = 0  -- 默认worker id
local sequence = 0
local last_timestamp = -1

-- 获取当前时间戳(毫秒)
local function get_current_time()
    local time = math.floor(skynet.time() * 1000)
    return time
end

-- 等待下一毫秒
local function wait_next_millis(last)
    local timestamp = get_current_time()
    while timestamp <= last do
        timestamp = get_current_time()
    end
    return timestamp
end

-- 设置worker id
function M.set_worker_id(id)
    assert(id >= 0 and id <= MAX_WORKER_ID, "worker id out of range")
    worker_id = id
end

-- 生成下一个ID
function M.next_id(type_id)
    -- 检查类型ID
    assert(type_id >= 0 and type_id <= MAX_TYPE_ID, "type id out of range")
    
    local timestamp = get_current_time()
    
    -- 检查时钟回拨
    if timestamp < last_timestamp then
        error(string.format("Clock moved backwards. Refusing to generate id for %d milliseconds",
            last_timestamp - timestamp))
    end
    
    -- 同一毫秒内
    if timestamp == last_timestamp then
        sequence = (sequence + 1) & MAX_SEQUENCE
        -- 序列号用完，等待下一毫秒
        if sequence == 0 then
            timestamp = wait_next_millis(last_timestamp)
        end
    else
        -- 不同毫秒，序列号重置
        sequence = 0
    end
    
    last_timestamp = timestamp
    
    -- 组装ID
    local id = ((timestamp - EPOCH) << TIMESTAMP_SHIFT) |
               (type_id << TYPE_SHIFT) |
               (worker_id << WORKER_SHIFT) |
               sequence
    logger.info("snowflake: type_id: %d, next_id: %d", type_id, id)
    return id
end

-- 从ID中解析类型
function M.get_type(id)
    return (id >> TYPE_SHIFT) & MAX_TYPE_ID
end

-- 可以添加一个解析ID的函数来验证
function M.parse_id(id)
    local sequence = id & MAX_SEQUENCE
    local worker = (id >> WORKER_SHIFT) & MAX_WORKER_ID
    local type_id = (id >> TYPE_SHIFT) & MAX_TYPE_ID
    local timestamp = (id >> TIMESTAMP_SHIFT) + EPOCH
    
    return {
        sequence = sequence,
        worker_id = worker,
        type_id = type_id,
        timestamp = timestamp,
        original = id
    }
end

return M