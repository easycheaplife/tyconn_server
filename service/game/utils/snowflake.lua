local skynet = require "skynet"

local M = {}

-- 时间戳位数
local TIMESTAMP_BITS = 41
-- 机器ID位数
local WORKER_BITS = 10
-- 序列号位数
local SEQUENCE_BITS = 12

-- 起始时间戳 (2024-01-01 00:00:00)
local EPOCH = 1704038400000

-- 最大值
local MAX_SEQUENCE = (1 << SEQUENCE_BITS) - 1
local MAX_WORKER_ID = (1 << WORKER_BITS) - 1

-- 位移
local TIMESTAMP_SHIFT = WORKER_BITS + SEQUENCE_BITS
local WORKER_SHIFT = SEQUENCE_BITS

-- 当前序列号
local sequence = 0
-- 上次生成ID的时间戳
local last_timestamp = 0

-- 获取当前时间戳(毫秒)
local function get_current_timestamp()
    return skynet.time() * 1000
end

-- 等待下一毫秒
local function wait_next_millis(last)
    local timestamp = get_current_timestamp()
    while timestamp <= last do
        timestamp = get_current_timestamp()
    end
    return timestamp
end

-- 生成唯一ID
function M.generate()
    local timestamp = get_current_timestamp()
    local worker_id = tonumber(skynet.getenv("node_id")) or 1

    -- 检查worker_id是否超出范围
    assert(worker_id <= MAX_WORKER_ID, "worker_id超出范围")

    -- 如果是同一毫秒
    if timestamp == last_timestamp then
        sequence = (sequence + 1) & MAX_SEQUENCE
        -- 如果序列号用完，等待下一毫秒
        if sequence == 0 then
            timestamp = wait_next_millis(last_timestamp)
        end
    else
        sequence = 0
    end

    last_timestamp = timestamp

    -- 生成ID
    return ((timestamp - EPOCH) << TIMESTAMP_SHIFT) |
           (worker_id << WORKER_SHIFT) |
           sequence
end

return M 