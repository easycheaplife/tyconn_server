local skynet = require "skynet"

-- 加载 snowflake 模块 (现在可以直接加载了)
local snowflake = require "game.utils.snowflake"

-- =================== 类型测试功能 ===================

-- 测试所有ID类型的唯一性
local function test_all_types(count_per_type)
    count_per_type = count_per_type or 1000
    
    skynet.error("开始测试所有类型ID的唯一性...")
    
    -- 构建类型名称映射表
    local type_names = {}
    for name, id in pairs(snowflake.ID_TYPE) do
        type_names[id] = name
    end
    
    local all_success = true
    local all_ids = {}   -- 存储所有生成的ID，检查全局唯一性
    
    -- 为每种类型生成ID并检查
    for id, name in pairs(type_names) do
        skynet.error(string.format("测试类型: %s (%d) - 生成 %d 个ID", 
                    name, id, count_per_type))
        
        local success = true
        local ids = {}
        
        for i = 1, count_per_type do
            local snowflake_id = snowflake.next_id(id)
            
            -- 检查类型内唯一性
            if ids[snowflake_id] then
                skynet.error(string.format("类型内重复: 类型 %s (%d) 发现重复ID: %d", 
                          name, id, snowflake_id))
                success = false
                all_success = false
            end
            
            -- 检查全局唯一性
            if all_ids[snowflake_id] then
                local other_type = all_ids[snowflake_id]
                skynet.error(string.format("跨类型重复: ID %d 在类型 %s (%d) 和类型 %s (%d) 间重复", 
                          snowflake_id, name, id, type_names[other_type], other_type))
                success = false
                all_success = false
            end
            
            ids[snowflake_id] = true
            all_ids[snowflake_id] = id  -- 记录ID属于哪个类型
        end
        
        skynet.error(string.format("类型 %s (%d) 测试%s", 
                    name, id, success and "通过" or "失败"))
    end
    
    skynet.error(string.format("所有类型ID测试%s", 
                all_success and "通过" or "失败"))
    
    return all_success
end

-- =================== 基础测试功能 ===================

-- 基本唯一性测试
local function test_uniqueness(type_id, count)
    type_id = type_id or snowflake.ID_TYPE.ITEM
    count = count or 10000
    
    skynet.error(string.format("基本唯一性测试: 类型 %d, 数量 %d", type_id, count))
    
    local ids = {}
    local duplicates = 0
    local start_time = skynet.time()
    
    -- 生成指定数量的ID
    for i = 1, count do
        local id = snowflake.next_id(type_id)
        if ids[id] then
            duplicates = duplicates + 1
            skynet.error(string.format("发现重复ID: %d (位置: %d)", id, i))
        end
        ids[id] = true
    end
    
    local end_time = skynet.time()
    local elapsed = (end_time - start_time) * 1000
    
    skynet.error(string.format("基本唯一性测试结果: 生成 %d 个ID, %.2f ms (%.2f IDs/ms), 重复 %d 个", 
                count, elapsed, count / elapsed, duplicates))
    
    -- 检查第一个和最后一个ID
    local first_id, last_id
    for id, _ in pairs(ids) do
        if not first_id or id < first_id then first_id = id end
        if not last_id or id > last_id then last_id = id end
    end
    
    if first_id and last_id then
        local first_info = snowflake.parse_id(first_id)
        local last_info = snowflake.parse_id(last_id)
        
        skynet.error(string.format("首个ID: %d (时间戳: %d, 序列号: %d)", 
                    first_info.original, first_info.timestamp, first_info.sequence))
        skynet.error(string.format("末个ID: %d (时间戳: %d, 序列号: %d)", 
                    last_info.original, last_info.timestamp, last_info.sequence))
    end
    
    return duplicates == 0
end

-- =================== 高级测试功能 ===================

-- 毫秒边界测试
local function millisecond_boundary_test(type_id, batch_size)
    type_id = type_id or snowflake.ID_TYPE.ITEM
    batch_size = batch_size or 1500 -- 每毫秒生成ID数量
    
    skynet.error(string.format("毫秒边界测试: 类型 %d, 每批 %d 个", type_id, batch_size))
    
    local ids = {}
    local current_ms = -1
    local batches = 0
    local duplicates = 0
    
    -- 持续测试，直到跨越至少5个毫秒边界
    while batches < 5 do
        local timestamp = math.floor(skynet.time() * 1000)
        
        -- 当检测到新的毫秒开始时，快速生成一批ID
        if timestamp > current_ms then
            batches = batches + 1
            current_ms = timestamp
            
            skynet.error(string.format("毫秒边界测试: 批次 %d, 时间戳 %d", batches, current_ms))
            
            for i = 1, batch_size do
                local id = snowflake.next_id(type_id)
                if ids[id] then
                    duplicates = duplicates + 1
                    skynet.error(string.format("毫秒边界测试: 发现重复ID %d (批次 %d, 位置 %d)", 
                                id, batches, i))
                end
                ids[id] = true
            end
        end
        
        -- 小暂停以等待下一个毫秒
        skynet.sleep(0)
    end
    
    skynet.error(string.format("毫秒边界测试结果: 生成约 %d 个ID, 发现 %d 个重复", 
                batches * batch_size, duplicates))
    
    return duplicates == 0
end

-- 高速连续生成测试
local function burst_test(type_id, burst_count)
    type_id = type_id or snowflake.ID_TYPE.ITEM
    burst_count = burst_count or 20000
    
    skynet.error(string.format("高速连续生成测试: 类型 %d, 数量 %d", type_id, burst_count))
    
    local ids = {}
    local duplicates = 0
    local start_time = skynet.time()
    
    -- 尽可能快地生成ID
    for i = 1, burst_count do
        local id = snowflake.next_id(type_id)
        if ids[id] then
            duplicates = duplicates + 1
            skynet.error(string.format("高速测试: 发现重复ID %d (位置 %d)", id, i))
        end
        ids[id] = true
    end
    
    local elapsed = (skynet.time() - start_time)
    skynet.error(string.format("高速测试结果: %.2f秒生成 %d 个ID (%.2f IDs/秒), 发现 %d 个重复", 
                elapsed, burst_count, burst_count/elapsed, duplicates))
    
    return duplicates == 0
end

-- 序列号溢出测试
local function sequence_overflow_test(type_id)
    type_id = type_id or snowflake.ID_TYPE.ITEM
    
    skynet.error(string.format("序列号溢出测试: 类型 %d", type_id))
    
    -- 计算最大序列号 (基于 snowflake.lua 中的配置)
    local max_sequence = (1 << 10) - 1 -- 假设 SEQUENCE_BITS = 10
    local test_count = max_sequence + 100
    
    skynet.error(string.format("最大序列号: %d, 测试数量: %d", max_sequence, test_count))
    
    local start_ms = math.floor(skynet.time() * 1000)
    local ids = {}
    local duplicates = 0
    
    -- 尝试在同一毫秒内生成超过序列号上限的ID
    for i = 1, test_count do
        local id = snowflake.next_id(type_id)
        if ids[id] then
            duplicates = duplicates + 1
            skynet.error(string.format("序列号溢出测试: 发现重复ID %d (位置 %d)", id, i))
        end
        ids[id] = true
        
        -- 检查是否已经跨越毫秒边界
        local current_ms = math.floor(skynet.time() * 1000)
        if current_ms > start_ms + 5 then
            break -- 如果已经过了5毫秒还没完成，就提前结束测试
        end
    end
    
    local count = 0
    for _ in pairs(ids) do count = count + 1 end
    
    skynet.error(string.format("序列号溢出测试结果: 尝试生成 %d 个ID, 实际生成 %d 个, 发现 %d 个重复", 
                test_count, count, duplicates))
    
    -- 分析结果：我们期望当序列号用尽时，算法等待下一毫秒
    local success = duplicates == 0
    if count < test_count then
        skynet.error("序列号溢出测试结果: 算法正确地在序列号用尽时等待下一毫秒")
    else
        skynet.error("警告: 能够在单个毫秒内生成超过最大序列号的ID数量，请检查算法")
        success = false
    end
    
    return success
end

-- 多worker测试
local function multi_worker_test(workers_count, ids_per_worker)
    workers_count = workers_count or 5
    ids_per_worker = ids_per_worker or 1000
    
    skynet.error(string.format("多worker测试: %d 个worker, 每个生成 %d 个ID", 
                workers_count, ids_per_worker))
    
    local all_ids = {}
    local duplicates = 0
    
    -- 模拟不同worker生成ID
    for worker = 0, workers_count - 1 do
        skynet.error(string.format("多worker测试: worker %d 开始生成ID", worker))
        snowflake.set_worker_id(worker)
        
        for i = 1, ids_per_worker do
            local id = snowflake.next_id(snowflake.ID_TYPE.ITEM)
            if all_ids[id] then
                duplicates = duplicates + 1
                skynet.error(string.format("多worker测试: 发现重复ID %d (worker: %d, 位置: %d, 与worker %d冲突)", 
                            id, worker, i, all_ids[id].worker))
            else
                all_ids[id] = {worker = worker, pos = i}
            end
        end
    end
    
    -- 重置worker ID为默认值
    snowflake.set_worker_id(0)
    
    skynet.error(string.format("多worker测试结果: 生成 %d 个ID, 发现 %d 个重复", 
                workers_count * ids_per_worker, duplicates))
    
    return duplicates == 0
end

-- =================== 主测试入口 ===================

skynet.start(function()
    skynet.error("========== Snowflake ID 综合测试开始 ==========")
    
    -- 运行所有测试
    local test_results = {
        types_test = test_all_types(500),
        uniqueness_test = test_uniqueness(snowflake.ID_TYPE.ITEM, 10000),
        boundary_test = millisecond_boundary_test(snowflake.ID_TYPE.ITEM, 1500),
        burst_test = burst_test(snowflake.ID_TYPE.ITEM, 20000),
        overflow_test = sequence_overflow_test(snowflake.ID_TYPE.ITEM),
        worker_test = multi_worker_test(5, 1000)
    }
    
    -- 统计结果
    local pass_count = 0
    local total_count = 0
    
    skynet.error("\n========== 测试结果摘要 ==========")
    for name, result in pairs(test_results) do
        total_count = total_count + 1
        if result then pass_count = pass_count + 1 end
        skynet.error(string.format("  %s: %s", name, result and "通过" or "失败"))
    end
    
    skynet.error(string.format("\n总结: 通过 %d/%d 测试用例 (%.1f%%)", 
                pass_count, total_count, pass_count * 100 / total_count))
    
    if pass_count == total_count then
        skynet.error("所有测试通过! Snowflake ID 生成器工作正常")
    else
        skynet.error("警告: 部分测试失败，请检查 Snowflake ID 生成器实现")
    end
    
    skynet.error("========== 测试结束 ==========")
    skynet.exit()
end)