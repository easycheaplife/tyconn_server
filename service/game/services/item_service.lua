local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local cjson = require "cjson"
local item_model = require "models.item_model"
local item_dao = require "dao.item_dao"
local user_service = require "services.user_service"
local snowflake = require "utils.snowflake"
local bag_dao = require "dao.bag_dao"
local property_service = require "services.property_service"
local bag_model = require "models.bag_model"
local utils = require "utils"

local M = {}

-- 物品配置
local ITEM_CONFIG = {}

-- 加载物品配置
function M.init_item_config()
    -- 读取配置文件
    local file, err = io.open("config/Dfw_item.json", "r")
    if not file then
        logger.error("Failed to open item config file: %s", err)
        return false
    end

    -- 读取文件内容
    local content = file:read("*a")
    file:close()

    -- 解析 JSON
    local ok, config = pcall(cjson.decode, content)
    if not ok then
        logger.error("Failed to decode item config JSON: %s", config)
        return false
    end

    -- 转换配置格式
    for id, item_data in pairs(config) do
        local item_id = tonumber(item_data.Item_id)
        if item_id then
            ITEM_CONFIG[item_id] = {
                id = item_id,
                name = item_data.L_name,
                type = tonumber(item_data.Type) or 1,
                quality = tonumber(item_data.Qua) or 1,
                class = tonumber(item_data.Class) or 1,
                max_stack = tonumber(item_data.Max) or 99,
                description = item_data.L_des,
                icon = item_data.Icon,
                show = tonumber(item_data.Show) or 0,
                order = tonumber(item_data.Order) or 0
            }
        end
    end

    -- 添加测试物品配置
    ITEM_CONFIG[1001] = ITEM_CONFIG[1001] or {}  -- 保留原有配置
    ITEM_CONFIG[1001].effect_type = item_model.EFFECT_TYPE.EXP
    ITEM_CONFIG[1001].effect_value = 100
    ITEM_CONFIG[1001].max_stack = 10000

    ITEM_CONFIG[2012] = ITEM_CONFIG[2012] or {}  -- 保留原有配置
    ITEM_CONFIG[2012].effect_type = item_model.EFFECT_TYPE.GOLD
    ITEM_CONFIG[2012].effect_value = 1000
    ITEM_CONFIG[2012].max_stack = 10000

    logger.info("Item config loaded: %d items", #ITEM_CONFIG)
    return true
end

-- 从配置文件读取新手默认物品
local DEFAULT_ITEMS = {}
function M.init_default_items()  -- 改为 M. 导出
    -- 读取配置文件
    local file, err = io.open("config/Dfw_Initial.json", "r")
    if not file then
        logger.error("Failed to open initial config file: %s", err)
        return
    end

    -- 读取文件内容
    local content = file:read("*a")
    file:close()

    -- 解析 JSON
    local ok, initial_config = pcall(cjson.decode, content)
    if not ok then
        logger.error("Failed to decode JSON: %s", initial_config)
        return
    end

    -- 获取第一个玩家的配置
    local player_config = initial_config["1"]
    if not player_config or not player_config.Item then
        logger.error("Invalid config format: %s", utils.table_to_string(initial_config))
        return
    end

    -- 转换配置格式
    for _, item_data in ipairs(player_config.Item) do
        table.insert(DEFAULT_ITEMS, {
            item_id = tonumber(item_data[1]),  -- 第一个元素是物品ID
            count = tonumber(item_data[2] or 1)  -- 第二个元素是数量，默认为1
        })
    end
    logger.info("Default items loaded: %d items", #DEFAULT_ITEMS)
end

-- 物品查询条件
local QUERY_CONDITION = {
    TYPE = 1,       -- 按类型查询
    QUALITY = 2,    -- 按品质查询
    LEVEL = 3,      -- 按等级查询
    EXPIRED = 4,    -- 按过期状态查询
    LOCKED = 5,     -- 按锁定状态查询
    NAME = 6,       -- 按名称查询
    TAG = 7,        -- 按标签查询
    EFFECT = 8,     -- 按效果查询
    CATEGORY = 9    -- 按分类查询
}

-- 排序规则
local SORT_RULE = {
    TYPE = 1,       -- 按类型排序
    QUALITY = 2,    -- 按品质排序
    LEVEL = 3,      -- 按等级排序
    COUNT = 4,      -- 按数量排序
    TIME = 5        -- 按时间排序
}

-- 获取物品排序权重
local function get_item_weight(item, rule)
    local config = ITEM_CONFIG[item.item_id]
    if not config then
        return 0
    end
    
    if rule == SORT_RULE.TYPE then
        return config.type * 10000 + config.quality * 100 + config.level
    elseif rule == SORT_RULE.QUALITY then
        return config.quality * 10000 + config.level * 100 + config.type
    elseif rule == SORT_RULE.LEVEL then
        return config.level * 10000 + config.quality * 100 + config.type
    elseif rule == SORT_RULE.COUNT then
        return item.count * 10000 + config.quality * 100 + config.type
    elseif rule == SORT_RULE.TIME then
        return (os.time() - item.create_time) * 10000 + config.type * 100 + config.quality
    end
    return 0
end

-- 应用物品效果
local function apply_item_effect(user_id, item_id, count)
    logger.debug("Applying item effect - user_id: %d, item_id: %d, count: %d", 
        user_id, item_id, count)
    local config = ITEM_CONFIG[item_id]
    if not config then
        return false, "物品配置不存在"
    end
    
    -- 2. 检查使用限制
    if config.use_limit then
        local limit_type = config.use_limit.type
        local limit_count = config.use_limit.count
        
        -- 获取已使用次数
        local used_count = item_dao.get_use_count(user_id, item_id)
        if not used_count then
            return false, "获取使用次数失败"
        end
        
        -- 检查是否超过限制
        if limit_type == item_model.USE_LIMIT_TYPE.DAILY then
            -- 检查是否跨天重置
            local last_use_time = item_dao.get_last_use_time(user_id, item_id)
            if last_use_time and not utils.is_same_day(last_use_time, os.time()) then
                used_count = 0
            end
        elseif limit_type == item_model.USE_LIMIT_TYPE.WEEKLY then
            -- 检查是否跨周重置
            local last_use_time = item_dao.get_last_use_time(user_id, item_id)
            if last_use_time and not utils.is_same_week(last_use_time, os.time()) then
                used_count = 0
            end
        end
        
        if used_count + count > limit_count then
            return false, "超过使用次数限制"
        end
        
        -- 更新使用次数
        local ok = item_dao.update_use_count(user_id, item_id, used_count + count)
        if not ok then
            return false, "更新使用次数失败"
        end
    end
    
    -- 3. 应用效果
    local total_effect = config.effect_value * count
    
    -- 根据效果类型处理
    if config.effect_type == item_model.EFFECT_TYPE.EXP then
        -- 增加经验
        local ok, err = user_service.add_exp(user_id, total_effect)
        if not ok then
            logger.error("Failed to add exp: %s", err)
            return false, err
        end
    elseif config.effect_type == item_model.EFFECT_TYPE.GOLD then
        -- 增加金币
        local ok, err = user_service.add_gold(user_id, total_effect)
        if not ok then
            logger.error("Failed to add gold: %s", err)
            return false, err
        end
    end
    
    return true
end

-- 添加物品到指定格子
function M.add_items_to_slot(user_id, items)
    if not user_id or not items then
        return false, "参数无效"
    end

    -- 1. 获取背包信息
    local bag = bag_dao.get_user_bag(user_id, bag_model.BAG_TYPE.MAIN)
    if not bag then
        -- 需要先创建背包
        logger.info("Creating main bag for user %d", user_id)
        bag = bag_dao.create_bag(user_id, bag_model.BAG_TYPE.MAIN, 20)  -- 默认20格
        if not bag then
            return false, "创建背包失败"
        end
    end

    -- 2. 检查背包空间
    local need_slots = #items
    local empty_slots = {}
    for _, slot in ipairs(bag.slots) do
        if slot.state == bag_model.SLOT_STATE.EMPTY then
            table.insert(empty_slots, slot)
        end
    end

    if #empty_slots < need_slots then
        return false, "背包空间不足"
    end

    -- 3. 获取当前物品列表(用于记录变化)
    local current_items = item_dao.get_user_items(user_id) or {}
    local item_map = {}
    for _, item in ipairs(current_items) do
        item_map[item.item_id] = item
    end

    -- 4. 创建物品实例并记录变化
    local new_items = {}
    for i, item in ipairs(items) do
        -- 创建新物品
        local new_item = item_model.new({
            id = item.id or snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = user_id,
            item_id = item.item_id,
            count = item.count or 1,
            bag_type = bag_model.BAG_TYPE.MAIN,
            slot_index = empty_slots[i].slot_index,
            create_time = os.time(),
            update_time = os.time()
        })
        
        table.insert(new_items, new_item)
        
        -- 记录物品变化
        local before_count = item_map[item.item_id] and item_map[item.item_id].count or 0
        item_dao.log_change(
            user_id,
            item.item_id,
            item.count,
            item_model.CHANGE_TYPE.ADD,
            item_model.CHANGE_SOURCE.INIT,
            before_count,
            before_count + item.count
        )
    end
    
    -- 5. 保存物品
    local ok = item_dao.update_user_items(user_id, new_items)
    if not ok then
        return false, "保存物品失败"
    end

    -- 6. 更新格子状态
    for i, slot in ipairs(empty_slots) do
        if i > #items then break end
        bag_dao.update_slot_state(user_id, bag_model.BAG_TYPE.MAIN, slot.slot_index, bag_model.SLOT_STATE.NORMAL)
    end

    -- 7. 记录操作日志
    logger.info("Added items to slots - user_id: %d, items: %s", 
        user_id, utils.table_to_string(items))

    return true, new_items
end

-- 检查物品是否被锁定
local function check_item_locked(item)
    if not item then
        return false
    end
    
    -- 检查物品状态
    if item.state == item_model.ITEM_STATE.LOCKED then
        return true
    end
    
    -- 检查物品是否在交易中
    if item.trade_state and item.trade_state ~= item_model.TRADE_STATE.NONE then
        return true
    end
    
    -- 检查物品是否在拍卖中
    if item.auction_state and item.auction_state ~= item_model.AUCTION_STATE.NONE then
        return true
    end
    
    return false
end

-- 使用物品
function M.use_item(user_id, item_id, count)
    -- 1. 检查参数
    if not user_id or not item_id or not count or count <= 0 then
        return false, "参数错误"
    end
    
    -- 2. 获取物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 查找物品
    local target_item = nil
    local target_index = nil
    for i, item in ipairs(items) do
        if item.item_id == item_id then
            target_item = item
            target_index = i
            break
        end
    end
    
    if not target_item then
        return false, "物品不存在"
    end
    
    -- 4. 检查物品是否被锁定
    if check_item_locked(target_item) then
        return false, "物品已被锁定"
    end
    
    -- 检查物品数量是否足够
    if target_item.count < count then
        logger.error("物品数量不足 - user_id: %d, item_id: %d, count: %d, have: %d", 
            user_id, item_id, count, target_item.count)
        return false, pb.enum("common.ErrorCode", "ERROR_CODE_ITEM_NOT_ENOUGH")
    end

    -- 记录变更前数量
    local before_count = target_item.count
    
    -- 更新数量
    target_item.count = target_item.count - count
    target_item.update_time = os.time()
    
    -- 记录物品变化
    item_dao.log_change(user_id, item_id, count,
        item_model.CHANGE_TYPE.USE, item_model.CHANGE_SOURCE.USE,
        before_count, target_item.count)

    -- 如果物品数量为0，从列表中删除并清空格子
    if target_item.count <= 0 then
        -- 保存格子信息
        local bag_type = target_item.bag_type
        local slot_index = target_item.slot_index
        
        -- 从列表中删除
        table.remove(items, target_index)
        
        -- 更新格子状态为空
        if bag_type and slot_index then
            bag_dao.update_slot_state(user_id, bag_type, slot_index, bag_model.SLOT_STATE.EMPTY)
        end
    end

    -- 更新数据库和缓存
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR")
    end

    -- 应用物品效果
    local ok, err = apply_item_effect(user_id, item_id, count)
    if not ok then
        logger.error("Failed to apply item effect - user_id: %d, item_id: %d, error: %s",
            user_id, item_id, err)
        return false, err
    end

    -- 记录操作日志
    logger.info("Used item - user_id: %d, item_id: %d, count: %d, remain: %d",
        user_id, item_id, count, target_item.count)

    -- 返回变化的物品列表
    return true, {target_item}
end

-- 初始化新用户物品
function M.init_user_items(user_id)
    if not user_id then
        return false, "无效的用户ID"
    end

    logger.info("Initializing items for user: %d", user_id)

    -- 1. 创建主背包
    local bag = bag_dao.get_user_bag(user_id, bag_model.BAG_TYPE.MAIN)
    if not bag then
        bag = bag_dao.create_bag(user_id, bag_model.BAG_TYPE.MAIN, 20)  -- 默认20格
        if not bag then
            return false, "创建背包失败"
        end
    end

    -- 2. 添加默认物品
    if #DEFAULT_ITEMS > 0 then
        local ok, err = M.add_items_to_slot(user_id, DEFAULT_ITEMS)
        if not ok then
            logger.error("Failed to add default items for user %d: %s", user_id, err)
            return false, err
        end
    end

    return true
end

-- 获取用户物品列表
function M.get_user_items(user_id)
    if not user_id then
        return nil, "无效的用户ID"
    end

    -- 从 dao 层获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        -- 新用户，返回空列表
        return {}
    end
    logger.info("items: %s", utils.table_to_string(items))
    return items
end

-- 检查物品数据是否有效
local function validate_item(item)
    -- 1. 基础检查
    local ok, err = item_model.validate(item)
    if not ok then
        return false, err
    end
    
    -- 2. 检查物品配置
    local config = ITEM_CONFIG[item.item_id]
    if not config then
        return false, "物品配置不存在"
    end
    
    -- 3. 检查堆叠数量
    if config.max_stack and item.count > config.max_stack then
        return false, "超过最大堆叠数量"
    end
    
    return true
end

-- 修复物品数据
function M.repair_user_items(user_id)
    -- 1. 获取物品列表
    local items = item_dao.get_user_items(user_id)
    if not items then
        return true
    end
    
    -- 2. 检查并修复每个物品
    local valid_items = {}
    for _, item in ipairs(items) do
        local ok, err = validate_item(item)
        if ok then
            table.insert(valid_items, item)
        else
            logger.error("Invalid item found for user %d: %s", 
                user_id, utils.table_to_string(item))
        end
    end
    
    -- 3. 保存修复后的数据
    if #valid_items < #items then
        local ok = item_dao.update_user_items(user_id, valid_items)
        if not ok then
            return false, "保存物品数据失败"
        end
    end
    
    return true
end

-- 获取物品合成配置
local function get_compose_config(item_id)
    local config = require("config.compose_config")[item_id]
    if not config then
        return nil
    end
    return config
end

-- 检查合成材料是否足够
local function check_compose_materials(items, materials)
    local material_count = {}
    -- 统计现有材料
    for _, item in ipairs(items) do
        material_count[item.item_id] = (material_count[item.item_id] or 0) + item.count
    end
    
    -- 检查是否满足需求
    for item_id, need_count in pairs(materials) do
        if (material_count[item_id] or 0) < need_count then
            return false
        end
    end
    
    return true
end

-- 合成物品
function M.compose_item(user_id, target_id)
    -- 1. 获取合成配置
    local compose_config = get_compose_config(target_id)
    if not compose_config then
        return false, "物品不可合成"
    end
    
    -- 2. 获取用户物品
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 检查材料是否足够
    if not check_compose_materials(items, compose_config.materials) then
        return false, "材料不足"
    end
    
    -- 4. 扣除材料
    for item_id, need_count in pairs(compose_config.materials) do
        local remain_count = need_count
        for i = #items, 1, -1 do
            if items[i].item_id == item_id then
                local use_count = math.min(remain_count, items[i].count)
                items[i].count = items[i].count - use_count
                remain_count = remain_count - use_count
                
                -- 记录物品变化
                item_dao.log_change(user_id, item_id, use_count,
                    item_model.CHANGE_TYPE.REDUCE, item_model.CHANGE_SOURCE.COMPOSE,
                    items[i].count + use_count, items[i].count)
                
                if items[i].count <= 0 then
                    table.remove(items, i)
                end
                
                if remain_count <= 0 then
                    break
                end
            end
        end
    end
    
    -- 5. 随机判定是否成功
    local result = item_model.COMPOSE_RESULT.SUCCESS
    if compose_config.success_rate then
        if math.random() > compose_config.success_rate then
            result = compose_config.fail_keep_material and 
                item_model.COMPOSE_RESULT.FAIL or 
                item_model.COMPOSE_RESULT.FAIL_CONSUME
        end
    end
    
    -- 6. 处理结果
    if result == item_model.COMPOSE_RESULT.SUCCESS then
        -- 添加合成物品
        local new_item = item_model.new({
            id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = user_id,
            item_id = target_id,
            count = compose_config.output_count or 1
        })
        table.insert(items, new_item)
        
        -- 记录物品变化
        item_dao.log_change(user_id, target_id, new_item.count,
            item_model.CHANGE_TYPE.ADD, item_model.CHANGE_SOURCE.COMPOSE,
            0, new_item.count)
    elseif result == item_model.COMPOSE_RESULT.FAIL then
        -- 返还材料
        for item_id, count in pairs(compose_config.materials) do
            local new_item = item_model.new({
                id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
                user_id = user_id,
                item_id = item_id,
                count = count
            })
            table.insert(items, new_item)
        end
    end
    
    -- 7. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true, result
end

-- 获取物品分解配置
local function get_decompose_config(item_id)
    local config = require("config.decompose_config")[item_id]
    if not config then
        return nil
    end
    return config
end

-- 分解物品
function M.decompose_item(user_id, item_id, count)
    -- 1. 获取分解配置
    local decompose_config = get_decompose_config(item_id)
    if not decompose_config then
        return false, "物品不可分解"
    end
    
    -- 2. 获取用户物品
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 查找要分解的物品
    local found = false
    for i, item in ipairs(items) do
        if item.item_id == item_id then
            -- 检查数量是否足够
            if item.count < count then
                return false, "物品数量不足"
            end
            
            -- 记录变更前数量
            local before_count = item.count
            
            -- 扣除物品
            item.count = item.count - count
            item.update_time = os.time()
            
            -- 记录物品变化
            item_dao.log_change(user_id, item_id, count,
                item_model.CHANGE_TYPE.REDUCE, item_model.CHANGE_SOURCE.DECOMPOSE,
                before_count, item.count)
            
            -- 如果数量为0则移除
            if item.count <= 0 then
                table.remove(items, i)
            end
            
            found = true
            break
        end
    end
    
    if not found then
        return false, "物品不存在"
    end
    
    -- 4. 添加分解产物
    for output_id, output_info in pairs(decompose_config.outputs) do
        -- 计算产出数量
        local output_count = output_info.count * count
        
        -- 随机额外产出
        if output_info.extra_rate and math.random() <= output_info.extra_rate then
            output_count = output_count + (output_info.extra_count or 1)
        end
        
        -- 创建新物品
        local new_item = item_model.new({
            id = snowflake.next_id(snowflake.ID_TYPE.ITEM),
            user_id = user_id,
            item_id = output_id,
            count = output_count
        })
        table.insert(items, new_item)
        
        -- 记录物品变化
        item_dao.log_change(user_id, output_id, output_count,
            item_model.CHANGE_TYPE.ADD, item_model.CHANGE_SOURCE.DECOMPOSE,
            0, output_count)
    end
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true
end

-- 检查物品是否过期
local function check_item_expired(item)
    -- 检查过期时间
    if item.expire_time and os.time() >= item.expire_time then
        return true
    end
    
    -- 检查使用限制
    if item.use_limit_type == item_model.USE_LIMIT_TYPE.TOTAL and 
        item.used_count >= item.use_limit_count then
        return true
    end
    
    return false
end

-- 批量移除物品
function M.batch_remove_items(user_id, item_list)
    -- 1. 参数检查
    if not user_id or not item_list or #item_list == 0 then
        return false, "参数无效"
    end
    
    -- 2. 获取当前物品
    local current_items = M.get_user_items(user_id)
    if not current_items then
        return false, "获取物品失败"
    end
    
    -- 3. 检查数量是否足够
    local need_count = {}
    for _, item_info in ipairs(item_list) do
        need_count[item_info.item_id] = (need_count[item_info.item_id] or 0) + item_info.count
    end
    
    local have_count = {}
    for _, item in ipairs(current_items) do
        have_count[item.item_id] = (have_count[item.item_id] or 0) + item.count
    end
    
    for item_id, count in pairs(need_count) do
        if (have_count[item_id] or 0) < count then
            return false, string.format("物品%d数量不足", item_id)
        end
    end
    
    -- 4. 批量移除
    for item_id, need_count in pairs(need_count) do
        local remain_count = need_count
        for i = #current_items, 1, -1 do
            if current_items[i].item_id == item_id then
                local remove_count = math.min(remain_count, current_items[i].count)
                current_items[i].count = current_items[i].count - remove_count
                remain_count = remain_count - remove_count
                
                -- 记录变化
                item_dao.log_change(user_id, item_id, remove_count,
                    item_model.CHANGE_TYPE.REDUCE, "batch_remove",
                    current_items[i].count + remove_count, current_items[i].count)
                
                -- 如果数量为0则移除
                if current_items[i].count <= 0 then
                    table.remove(current_items, i)
                end
                
                if remain_count <= 0 then
                    break
                end
            end
        end
    end
    
    -- 5. 保存更新
    local ok = item_dao.update_user_items(user_id, current_items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true
end

-- 交易物品
function M.trade_items(from_user, to_user, item_list)
    -- 1. 参数检查
    if not from_user or not to_user or not item_list or #item_list == 0 then
        return false, "参数无效"
    end
    
    -- 2. 检查是否可交易
    for _, item_info in ipairs(item_list) do
        -- 检查是否被锁定
        local items = M.get_user_items(from_user)
        for _, item in ipairs(items) do
            if item.item_id == item_info.item_id then
                local locked, err = check_item_locked(item)
                if locked then
                    return false, err
                end
                break
            end
        end
        
        -- 获取物品配置
        local config = ITEM_CONFIG[item_info.item_id]
        if not config then
            return false, string.format("物品%d配置不存在", item_info.item_id)
        end
        
        -- 检查是否可交易
        if config.no_trade then
            return false, string.format("物品%d不可交易", item_info.item_id)
        end
    end
    
    -- 3. 从源用户移除物品
    local ok, err = M.batch_remove_items(from_user, item_list)
    if not ok then
        return false, err
    end
    
    -- 4. 添加物品到目标用户
    ok, err = M.add_items_to_slot(to_user, item_list)
    if not ok then
        -- 交易失败，回滚源用户物品
        M.add_items_to_slot(from_user, item_list)
        return false, err
    end
    
    -- 5. 记录交易日志
    for _, item_info in ipairs(item_list) do
        item_dao.log_trade(from_user, to_user, item_info.item_id, item_info.count)
    end
    
    return true
end

-- 锁定物品
function M.lock_item(user_id, item_id, lock_type, reason)
    -- 1. 参数检查
    if not user_id or not item_id then
        return false, "参数无效"
    end
    
    -- 2. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 查找并锁定物品
    local found = false
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            -- 检查是否已锁定
            local locked, err = check_item_locked(item)
            if locked then
                return false, err
            end
            
            -- 锁定物品
            item.lock_type = lock_type or item_model.LOCK_TYPE.USER
            item.lock_time = os.time()
            item.lock_reason = reason
            item.update_time = os.time()
            
            -- 记录变化
            item_dao.log_change(user_id, item_id, item.count,
                item_model.CHANGE_TYPE.LOCK, item_model.CHANGE_SOURCE.LOCK,
                item.count, item.count)
            
            found = true
            break
        end
    end
    
    if not found then
        return false, "物品不存在"
    end
    
    -- 4. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true
end

-- 解锁物品
function M.unlock_item(user_id, item_id)
    -- 1. 参数检查
    if not user_id or not item_id then
        return false, "参数无效"
    end
    
    -- 2. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 3. 查找并解锁物品
    local found = false
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            -- 检查是否已锁定
            local locked = check_item_locked(item)
            if not locked then
                return false, "物品未锁定"
            end
            
            -- 解锁物品
            item.lock_type = item_model.LOCK_TYPE.NONE
            item.lock_time = nil
            item.lock_reason = nil
            item.update_time = os.time()
            
            -- 记录变化
            item_dao.log_change(user_id, item_id, item.count,
                item_model.CHANGE_TYPE.UNLOCK, item_model.CHANGE_SOURCE.UNLOCK,
                item.count, item.count)
            
            found = true
            break
        end
    end
    
    if not found then
        return false, "物品不存在"
    end
    
    -- 4. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    return true
end

-- 过滤物品列表
local function filter_items(items, conditions)
    if not conditions or #conditions == 0 then
        return items
    end
    
    local result = {}
    for _, item in ipairs(items) do
        local match = true
        for _, condition in ipairs(conditions) do
            local config = ITEM_CONFIG[item.item_id]
            if not config then
                match = false
                break
            end
            
            if condition.type == QUERY_CONDITION.TYPE then
                if config.type ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.QUALITY then
                if config.quality ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.LEVEL then
                if config.level < condition.min or config.level > condition.max then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.EXPIRED then
                if check_item_expired(item) ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.LOCKED then
                local locked = (item.lock_type ~= item_model.LOCK_TYPE.NONE)
                if locked ~= condition.value then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.TAG then
                if not check_item_tags(item, condition.tags) then
                    match = false
                    break
                end
            elseif condition.type == QUERY_CONDITION.CATEGORY then
                if get_item_category(item) ~= condition.value then
                    match = false
                    break
                end
            end
        end
        
        if match then
            table.insert(result, item)
        end
    end
    
    return result
end

-- 查询用户物品
function M.query_user_items(user_id, conditions)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return {}
    end
    
    -- 2. 应用过滤条件
    local filtered = filter_items(items, conditions)
    
    -- 3. 按条件排序
    if conditions and conditions.sort_by then
        table.sort(filtered, function(a, b)
            local config_a = ITEM_CONFIG[a.item_id]
            local config_b = ITEM_CONFIG[b.item_id]
            
            if conditions.sort_by == "quality" then
                if config_a.quality == config_b.quality then
                    return a.item_id < b.item_id
                end
                return config_a.quality > config_b.quality
            elseif conditions.sort_by == "level" then
                if config_a.level == config_b.level then
                    return a.item_id < b.item_id
                end
                return config_a.level > config_b.level
            elseif conditions.sort_by == "count" then
                if a.count == b.count then
                    return a.item_id < b.item_id
                end
                return a.count > b.count
            end
            
            return a.item_id < b.item_id
        end)
    end
    
    return filtered
end

-- 统计物品数量
function M.count_user_items(user_id, conditions)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return 0
    end
    
    -- 2. 应用过滤条件
    local filtered = filter_items(items, conditions)
    
    -- 3. 统计数量
    local total_count = 0
    for _, item in ipairs(filtered) do
        total_count = total_count + item.count
    end
    
    return total_count
end

-- 获取物品最大堆叠数
local function get_max_stack(item_id)
    local config = ITEM_CONFIG[item_id]   
    if not config then
        return 1
    end
    return config.max_stack or 1
end

-- 堆叠物品
function M.stack_items(user_id, bag_type, from_slot, to_slot)
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)  -- 直接使用 dao 层
    if not bag then
        return false, "获取背包失败"
    end
    
    -- 2. 检查格子
    if not bag.slots[from_slot] or not bag.slots[to_slot] then
        return false, "格子不存在"
    end
    
    -- 3. 检查源格子和目标格子
    local src_slot = bag.slots[from_slot]
    local dst_slot = bag.slots[to_slot]
    
    if src_slot.state ~= item_model.SLOT_STATE.OCCUPIED then
        return false, "源格子没有物品"
    end
    
    if dst_slot.state ~= item_model.SLOT_STATE.OCCUPIED then
        return false, "目标格子没有物品"
    end
    
    -- 4. 检查是否为同类物品
    if src_slot.item_id ~= dst_slot.item_id then
        return false, "不同类型的物品不能堆叠"
    end
    
    -- 5. 检查是否可堆叠
    local max_stack = get_max_stack(src_slot.item_id)
    if max_stack <= 1 then
        return false, "物品不可堆叠"
    end
    
    -- 6. 计算可堆叠数量
    local can_stack = max_stack - dst_slot.count
    if can_stack <= 0 then
        return false, "目标格子已达到最大堆叠数"
    end
    
    -- 7. 执行堆叠
    local stack_count = math.min(can_stack, src_slot.count)
    
    -- 记录变更前数量
    local src_before = src_slot.count
    local dst_before = dst_slot.count
    
    -- 更新数量
    dst_slot.count = dst_slot.count + stack_count
    src_slot.count = src_slot.count - stack_count
    
    -- 记录物品变化
    item_dao.log_change(user_id, src_slot.item_id, stack_count,
        item_model.CHANGE_TYPE.REDUCE, "stack",
        src_before, src_slot.count)
    
    item_dao.log_change(user_id, dst_slot.item_id, stack_count,
        item_model.CHANGE_TYPE.ADD, "stack",
        dst_before, dst_slot.count)
    
    -- 如果源格子数量为0，清空格子
    if src_slot.count <= 0 then
        bag.slots[from_slot] = {
            index = from_slot,
            state = item_model.SLOT_STATE.EMPTY
        }
    end
    
    -- 8. 保存更新
    local ok = bag_dao.update_user_bag(user_id, bag_type, bag)
    if not ok then
        return false, "保存背包失败"
    end
    
    return true
end

-- 快速堆叠
function M.quick_stack(user_id, bag_type)
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)  -- 直接使用 dao 层
    if not bag then
        return false, "获取背包失败"
    end
    
    -- 2. 遍历所有格子尝试堆叠
    local need_update = false
    for i = 1, bag.size do
        local src_slot = bag.slots[i]
        if src_slot.state == item_model.SLOT_STATE.OCCUPIED then
            -- 查找可堆叠的目标格子
            for j = 1, i-1 do
                local dst_slot = bag.slots[j]
                if dst_slot.state == item_model.SLOT_STATE.OCCUPIED and
                    dst_slot.item_id == src_slot.item_id then
                    -- 尝试堆叠
                    local ok = M.stack_items(user_id, bag_type, i, j)
                    if ok then
                        need_update = true
                        break
                    end
                end
            end
        end
    end
    
    return true, need_update
end

-- 整理背包
function M.sort_bag(user_id, bag_type, rule)
    -- 1. 获取背包
    local bag = bag_dao.get_user_bag(user_id, bag_type)  -- 直接使用 dao 层
    if not bag then
        return false, "获取背包失败"
    end
    
    -- 2. 收集所有物品
    local items = {}
    for _, slot in pairs(bag.slots) do
        if slot.state == item_model.SLOT_STATE.OCCUPIED then
            table.insert(items, slot)
        end
    end
    
    -- 3. 按规则排序
    table.sort(items, function(a, b)
        local weight_a = get_item_weight(a, rule or SORT_RULE.TYPE)
        local weight_b = get_item_weight(b, rule or SORT_RULE.TYPE)
        if weight_a == weight_b then
            return a.item_id < b.item_id
        end
        return weight_a > weight_b
    end)
    
    -- 4. 重新放置物品
    local slot_index = 1
    for i = 1, bag.size do
        if i <= #items then
            -- 放置物品
            bag.slots[i] = items[i]
            bag.slots[i].index = i
        else
            -- 清空格子
            bag.slots[i] = {
                index = i,
                state = item_model.SLOT_STATE.EMPTY
            }
        end
    end
    
    -- 5. 保存更新
    local ok = bag_dao.update_user_bag(user_id, bag_type, bag)
    if not ok then
        return false, "保存背包失败"
    end
    
    return true
end

-- 整理所有背包
function M.sort_all_bags(user_id, rule)
    -- 1. 检查用户ID
    if not user_id then
        return false, "无效的用户ID"
    end
    
    -- 2. 整理各类型背包
    local bag_types = {
        item_model.BAG_TYPE.MAIN,
        item_model.BAG_TYPE.STORAGE
    }
    
    for _, bag_type in ipairs(bag_types) do
        local ok, err = M.sort_bag(user_id, bag_type, rule)
        if not ok then
            logger.error("Failed to sort bag %d for user %d: %s", 
                bag_type, user_id, err)
        end
    end
    
    -- 3. 尝试堆叠
    for _, bag_type in ipairs(bag_types) do
        local ok, need_update = M.quick_stack(user_id, bag_type)
        if ok and need_update then
            -- 如果有堆叠，重新排序
            M.sort_bag(user_id, bag_type, rule)
        end
    end
    
    return true
end

-- 搜索物品
function M.search_items(user_id, keyword, options)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return {}
    end
    
    -- 2. 准备搜索选项
    options = options or {}
    local result = {}
    
    -- 3. 遍历物品
    for _, item in ipairs(items) do
        local config = ITEM_CONFIG[item.item_id]  
        if config then
            local match = false
            
            -- 按名称搜索
            if options.search_name then
                if string.find(config.name, keyword) then
                    match = true
                end
            end
            
            -- 按描述搜索
            if options.search_desc and config.description then
                if string.find(config.description, keyword) then
                    match = true
                end
            end
            
            -- 按标签搜索
            if options.search_tag and config.tags then
                for _, tag in ipairs(config.tags) do
                    if string.find(tag, keyword) then
                        match = true
                        break
                    end
                end
            end
            
            -- 按效果搜索
            if options.search_effect and config.effects then
                for _, effect in ipairs(config.effects) do
                    if string.find(effect.description, keyword) then
                        match = true
                        break
                    end
                end
            end
            
            if match then
                table.insert(result, item)
            end
        end
    end
    
    -- 4. 应用过滤条件
    if options.conditions then
        result = filter_items(result, options.conditions)
    end
    
    -- 5. 应用排序
    if options.sort_by then
        table.sort(result, function(a, b)
            local config_a = ITEM_CONFIG[a.item_id]   
            local config_b = ITEM_CONFIG[b.item_id]
            
            if options.sort_by == "name" then
                return config_a.name < config_b.name
            elseif options.sort_by == "quality" then
                if config_a.quality == config_b.quality then
                    return config_a.name < config_b.name
                end
                return config_a.quality > config_b.quality
            elseif options.sort_by == "count" then
                if a.count == b.count then
                    return config_a.name < config_b.name
                end
                return a.count > b.count
            end
            
            return config_a.name < config_b.name
        end)
    end
    
    -- 6. 应用分页
    if options.page and options.page_size then
        local start = (options.page - 1) * options.page_size + 1
        local finish = start + options.page_size - 1
        local paged = {}
        for i = start, finish do
            if result[i] then
                table.insert(paged, result[i])
            end
        end
        result = paged
    end
    
    return result
end

-- 检查物品标签
local function check_item_tags(item, tags)
    local config = ITEM_CONFIG[item.item_id]  
    if not config or not config.tags then
        return false
    end
    
    -- 转换配置标签为集合
    local tag_set = {}
    for _, tag in ipairs(config.tags) do
        tag_set[tag] = true
    end
    
    -- 检查是否包含所有指定标签
    for _, tag in ipairs(tags) do
        if not tag_set[tag] then
            return false
        end
    end
    
    return true
end

-- 获取物品分类
local function get_item_category(item)
    local config = ITEM_CONFIG[item.item_id]  
    if not config then
        return item_model.ITEM_CATEGORY.OTHER
    end
    return config.category or item_model.ITEM_CATEGORY.OTHER
end

-- 按分类获取物品
function M.get_items_by_category(user_id, category)
    -- 1. 获取物品列表
    local items = M.get_user_items(user_id)
    if not items then
        return {}
    end
    
    -- 2. 过滤指定分类的物品
    local result = {}
    for _, item in ipairs(items) do
        if get_item_category(item) == category then
            table.insert(result, item)
        end
    end
    
    return result
end

-- 获取物品标签
function M.get_item_tags(item_id)
    local config = ITEM_CONFIG[item_id]   
    if not config then
        return {}
    end
    return config.tags or {}
end

-- 装备物品
function M.equip_item(user_id, item_id, slot_id)
    -- 1. 获取物品
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找物品
    local item = nil
    for _, it in ipairs(items) do
        if it.item_id == item_id then
            item = it
            break
        end
    end
    
    if not item then
        return false, "物品不存在"
    end
    
    -- 3. 检查物品类型
    local config = ITEM_CONFIG[item_id]   
    if not config or config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false, "物品不是装备"
    end
    
    -- 4. 检查装备槽位
    if not config.equip_slot or config.equip_slot ~= slot_id then
        return false, "装备槽位不匹配"
    end
    
    -- 5. 获取装备栏
    local equip_bag = bag_dao.get_user_bag(user_id, item_model.BAG_TYPE.EQUIP)  -- 直接使用 dao 层
    if not equip_bag then
        return false, "获取装备栏失败"
    end
    
    -- 6. 检查等级限制
    if config.level_required then
        local user_level = user_service.get_user_level(user_id)
        if user_level < config.level_required then
            return false, "等级不足"
        end
    end
    
    -- 7. 卸下当前装备
    local current_equip = equip_bag.slots[slot_id]
    if current_equip and current_equip.state == item_model.SLOT_STATE.OCCUPIED then
        -- 移动到背包
        local ok, err = M.unequip_item(user_id, slot_id)
        if not ok then
            return false, err
        end
    end
    
    -- 8. 装备新物品
    equip_bag.slots[slot_id] = {
        index = slot_id,
        state = item_model.SLOT_STATE.OCCUPIED,
        item_id = item_id,
        count = 1,
        equip_time = os.time()
    }
    
    -- 9. 从背包移除
    item.count = item.count - 1
    if item.count <= 0 then
        for i, it in ipairs(items) do
            if it.item_id == item_id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 10. 保存更新
    local ok = bag_dao.update_user_bag(user_id, item_model.BAG_TYPE.EQUIP, equip_bag)
    if not ok then
        return false, "保存装备栏失败"
    end
    
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存背包失败"
    end
    
    -- 11. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true
end

-- 卸下装备
function M.unequip_item(user_id, slot_id)
    -- 1. 获取装备栏
    local equip_bag = bag_dao.get_user_bag(user_id, item_model.BAG_TYPE.EQUIP)  -- 直接使用 dao 层
    if not equip_bag then
        return false, "获取装备栏失败"
    end
    
    -- 2. 检查装备槽位
    local equip = equip_bag.slots[slot_id]
    if not equip or equip.state ~= item_model.SLOT_STATE.OCCUPIED then
        return false, "装备槽位为空"
    end
    
    -- 3. 添加到背包
    local ok, err = M.add_items_to_slot(user_id, {
        {
            item_id = equip.item_id,
            count = 1
        }
    })
    if not ok then
        return false, err
    end
    
    -- 4. 清空装备槽位
    equip_bag.slots[slot_id] = {
        index = slot_id,
        state = item_model.SLOT_STATE.EMPTY
    }
    
    -- 5. 保存更新
    ok = bag_dao.update_user_bag(user_id, item_model.BAG_TYPE.EQUIP, equip_bag)
    if not ok then
        return false, "保存装备栏失败"
    end
    
    -- 6. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true
end

-- 获取装备强化配置
local function get_enhance_config(level)
    local config = require("config.enhance_config")[level]
    if not config then
        return nil
    end
    return config
end

-- 强化装备
function M.enhance_equipment(user_id, equip_id, material_list, protect_item)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "装备不存在"
    end
    
    -- 3. 检查装备类型
    local config = ITEM_CONFIG[equip.item_id] 
    if not config or config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false, "物品不是装备"
    end
    
    -- 4. 获取强化配置
    local enhance_level = equip.enhance_level or 0
    local enhance_config = get_enhance_config(enhance_level + 1)
    if not enhance_config then
        return false, "已达到最大强化等级"
    end
    
    -- 5. 检查材料
    local materials = {}
    local total_exp = 0
    for _, material in ipairs(material_list) do
        local mat_config = ITEM_CONFIG[material.item_id]
        if not mat_config then
            return false, "材料配置不存在"
        end
        
        if not mat_config.enhance_exp then
            return false, "物品不能用作强化材料"
        end
        
        total_exp = total_exp + mat_config.enhance_exp * material.count
        table.insert(materials, material)
    end
    
    if total_exp < enhance_config.need_exp then
        return false, "强化经验不足"
    end
    
    -- 6. 移除材料
    local ok, err = M.batch_remove_items(user_id, materials)
    if not ok then
        return false, err
    end
    
    -- 7. 计算强化结果
    local result = item_model.ENHANCE_RESULT.SUCCESS
    local enhance_type = item_model.ENHANCE_TYPE.NORMAL
    local random = math.random()
    
    if random <= enhance_config.perfect_rate then
        enhance_type = item_model.ENHANCE_TYPE.PERFECT
    elseif random <= enhance_config.success_rate then
        enhance_type = item_model.ENHANCE_TYPE.LUCKY
    else
        -- 失败处理
        if protect_item then
            -- 使用保护道具
            ok, err = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                -- 返还材料
                M.add_items_to_slot(user_id, materials)
                return false, err
            end
            result = item_model.ENHANCE_RESULT.FAIL
        else
            -- 随机失败结果
            if random <= enhance_config.break_rate then
                result = item_model.ENHANCE_RESULT.BREAK
            elseif random <= enhance_config.down_rate then
                result = item_model.ENHANCE_RESULT.FAIL_DOWN
            else
                result = item_model.ENHANCE_RESULT.FAIL
            end
        end
    end
    
    -- 8. 应用强化结果
    if result == item_model.ENHANCE_RESULT.SUCCESS or 
        result == item_model.ENHANCE_RESULT.PERFECT or
        result == item_model.ENHANCE_RESULT.LUCKY then
        -- 升级强化等级
        equip.enhance_level = enhance_level + 1
        
        -- 更新属性
        local props = {}
        for prop_type, base_value in pairs(config.base_props or {}) do
            local enhance_ratio = enhance_config.prop_ratio
            if enhance_type == item_model.ENHANCE_TYPE.PERFECT then
                enhance_ratio = enhance_ratio * 1.5
            elseif enhance_type == item_model.ENHANCE_TYPE.LUCKY then
                enhance_ratio = enhance_ratio * 1.2
            end
            props[prop_type] = math.floor(base_value * enhance_ratio)
        end
        equip.enhance_props = props
        
    elseif result == item_model.ENHANCE_RESULT.FAIL_DOWN then
        -- 降级
        equip.enhance_level = math.max(0, enhance_level - 1)
        
    elseif result == item_model.ENHANCE_RESULT.BREAK then
        -- 装备破碎
        for i, item in ipairs(items) do
            if item.id == equip_id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 9. 保存更新
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存装备失败"
    end
    
    -- 10. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        enhance_type = enhance_type,
        equip = equip
    }
end

-- 获取装备精炼配置
local function get_refine_config(level)
    local config = require("config.refine_config")[level]
    if not config then
        return nil
    end
    return config
end

-- 精炼装备
function M.refine_equipment(user_id, equip_id, material_list, protect_item)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "装备不存在"
    end
    
    -- 3. 检查装备类型
    local config = ITEM_CONFIG[equip.item_id] 
    if not config or config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false, "物品不是装备"
    end
    
    -- 4. 获取精炼配置
    local refine_level = equip.refine_level or 0
    local refine_config = get_refine_config(refine_level + 1)
    if not refine_config then
        return false, "已达到最大精炼等级"
    end
    
    -- 5. 检查材料
    local materials = {}
    local total_exp = 0
    for _, material in ipairs(material_list) do
        local mat_config = ITEM_CONFIG[material.item_id]
        if not mat_config then
            return false, "材料配置不存在"
        end
        
        if not mat_config.refine_exp then
            return false, "物品不能用作精炼材料"
        end
        
        total_exp = total_exp + mat_config.refine_exp * material.count
        table.insert(materials, material)
    end
    
    if total_exp < refine_config.need_exp then
        return false, "精炼经验不足"
    end
    
    -- 6. 移除材料
    local ok, err = M.batch_remove_items(user_id, materials)
    if not ok then
        return false, err
    end
    
    -- 7. 计算精炼结果
    local result = item_model.REFINE_RESULT.SUCCESS
    local random = math.random()
    
    if random > refine_config.success_rate then
        -- 失败处理
        if protect_item then
            -- 使用保护道具
            ok, err = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                -- 返还材料
                M.add_items_to_slot(user_id, materials)
                return false, err
            end
            result = item_model.REFINE_RESULT.FAIL
        else
            -- 随机失败结果
            if random <= refine_config.break_rate then
                result = item_model.REFINE_RESULT.BREAK
            elseif random <= refine_config.down_rate then
                result = item_model.REFINE_RESULT.FAIL_DOWN
            else
                result = item_model.REFINE_RESULT.FAIL
            end
        end
    end
    
    -- 8. 应用精炼结果
    if result == item_model.REFINE_RESULT.SUCCESS then
        -- 升级精炼等级
        equip.refine_level = refine_level + 1
        
        -- 更新属性
        local props = {}
        for prop_type, base_value in pairs(config.base_props or {}) do
            local refine_ratio = refine_config.prop_ratio
            props[prop_type] = math.floor(base_value * refine_ratio)
        end
        equip.refine_props = props
        
    elseif result == item_model.REFINE_RESULT.FAIL_DOWN then
        -- 降级
        equip.refine_level = math.max(0, refine_level - 1)
        
    elseif result == item_model.REFINE_RESULT.BREAK then
        -- 装备破碎
        for i, item in ipairs(items) do
            if item.id == equip_id then
                table.remove(items, i)
                break
            end
        end
    end
    
    -- 9. 保存更新
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存装备失败"
    end
    
    -- 10. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 洗练装备
function M.reforge_equipment(user_id, equip_id, material_list)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "装备不存在"
    end
    
    -- 3. 检查装备类型
    local config = ITEM_CONFIG[equip.item_id] 
    if not config or config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false, "物品不是装备"
    end
    
    -- 4. 检查材料
    local materials = {}
    local reforge_power = 0
    for _, material in ipairs(material_list) do
        local mat_config = ITEM_CONFIG[material.item_id]
        if not mat_config then
            return false, "材料配置不存在"
        end
        
        if not mat_config.reforge_power then
            return false, "物品不能用作洗练材料"
        end
        
        reforge_power = reforge_power + mat_config.reforge_power * material.count
        table.insert(materials, material)
    end
    
    -- 5. 移除材料
    local ok, err = M.batch_remove_items(user_id, materials)
    if not ok then
        return false, err
    end
    
    -- 6. 计算洗练结果
    local result = item_model.REFORGE_RESULT.SUCCESS
    local random = math.random()
    local perfect_rate = math.min(0.3, reforge_power * 0.01)
    
    if random <= perfect_rate then
        result = item_model.REFORGE_RESULT.PERFECT
    elseif random > 0.7 then
        result = item_model.REFORGE_RESULT.FAIL
    end
    
    -- 7. 生成新属性
    local new_props = {}
    if result ~= item_model.REFORGE_RESULT.FAIL then
        -- 保留固定属性
        for prop_type, value in pairs(equip.props or {}) do
            if config.fixed_props and config.fixed_props[prop_type] then
                new_props[prop_type] = value
            end
        end
        
        -- 随机新属性
        local random_prop_count = result == item_model.REFORGE_RESULT.PERFECT and 3 or 2
        for i = 1, random_prop_count do
            local prop_type = config.random_props[math.random(#config.random_props)]
            local base_value = config.prop_ranges[prop_type]
            local value = math.random(base_value[1], base_value[2])
            new_props[prop_type] = value
        end
        
        -- 特殊属性(完美洗练)
        if result == item_model.REFORGE_RESULT.PERFECT and config.special_props then
            local special_prop = config.special_props[math.random(#config.special_props)]
            new_props[special_prop.type] = special_prop.value
        end
    end
    
    -- 8. 应用洗练结果
    if result ~= item_model.REFORGE_RESULT.FAIL then
        equip.props = new_props
        equip.reforge_count = (equip.reforge_count or 0) + 1
    end
    
    -- 9. 保存更新
    ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存装备失败"
    end
    
    -- 10. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 镶嵌宝石
function M.inlay_gem(user_id, equip_id, gem_id, slot_index, protect_item)
    -- 1. 获取装备和宝石
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找装备和宝石
    local equip, gem = nil, nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
        elseif item.id == gem_id then
            gem = item
        end
    end
    
    if not equip then
        return false, "装备不存在"
    end
    if not gem then
        return false, "宝石不存在"
    end
    
    -- 3. 检查装备和宝石类型
    local equip_config = ITEM_CONFIG[equip.item_id]   
    local gem_config = ITEM_CONFIG[gem.item_id]
    
    if not equip_config or equip_config.type ~= item_model.ITEM_TYPE.EQUIPMENT then
        return false, "物品不是装备"
    end
    if not gem_config or gem_config.type ~= item_model.ITEM_TYPE.GEM then
        return false, "物品不是宝石"
    end
    
    -- 4. 检查槽位
    if not equip.gem_slots then
        equip.gem_slots = {}
    end
    
    if not equip.gem_slots[slot_index] then
        return false, "槽位不存在"
    end
    
    if equip.gem_slots[slot_index].state ~= item_model.GEM_SLOT_STATE.EMPTY then
        return false, "槽位已被占用"
    end
    
    -- 5. 检查宝石等级限制
    if gem_config.level_required and gem_config.level_required > equip_config.level then
        return false, "装备等级不足"
    end
    
    -- 6. 计算镶嵌结果
    local result = item_model.GEM_RESULT.SUCCESS
    local random = math.random()
    
    if random > gem_config.inlay_rate then
        -- 失败处理
        if protect_item then
            -- 使用保护道具
            local ok, err = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                return false, err
            end
            result = item_model.GEM_RESULT.FAIL
        else
            result = item_model.GEM_RESULT.BREAK
        end
    end
    
    -- 7. 应用镶嵌结果
    if result == item_model.GEM_RESULT.SUCCESS then
        -- 移除宝石
        gem.count = gem.count - 1
        if gem.count <= 0 then
            for i, item in ipairs(items) do
                if item.id == gem_id then
                    table.remove(items, i)
                    break
                end
            end
        end
        
        -- 镶嵌到装备
        equip.gem_slots[slot_index] = {
            state = item_model.GEM_SLOT_STATE.OCCUPIED,
            gem_id = gem.item_id,
            inlay_time = os.time()
        }
        
        -- 更新装备属性
        if not equip.gem_props then
            equip.gem_props = {}
        end
        
        for prop_type, value in pairs(gem_config.props or {}) do
            equip.gem_props[prop_type] = (equip.gem_props[prop_type] or 0) + value
        end
        
    elseif result == item_model.GEM_RESULT.BREAK then
        -- 宝石破碎
        gem.count = gem.count - 1
        if gem.count <= 0 then
            for i, item in ipairs(items) do
                if item.id == gem_id then
                    table.remove(items, i)
                    break
                end
            end
        end
    end
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存物品失败"
    end
    
    -- 9. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 卸下宝石
function M.remove_gem(user_id, equip_id, slot_index, protect_item)
    -- 1. 获取装备
    local items = M.get_user_items(user_id)
    if not items then
        return false, "获取物品失败"
    end
    
    -- 2. 查找装备
    local equip = nil
    for _, item in ipairs(items) do
        if item.id == equip_id then
            equip = item
            break
        end
    end
    
    if not equip then
        return false, "装备不存在"
    end
    
    -- 3. 检查槽位
    if not equip.gem_slots or not equip.gem_slots[slot_index] then
        return false, "槽位不存在"
    end
    
    local slot = equip.gem_slots[slot_index]
    if slot.state ~= item_model.GEM_SLOT_STATE.OCCUPIED then
        return false, "槽位没有宝石"
    end
    
    -- 4. 计算卸下结果
    local result = item_model.GEM_RESULT.SUCCESS
    local random = math.random()
    
    if random > 0.7 then  -- 30%概率失败
        if protect_item then
            -- 使用保护道具
            local ok, err = M.use_item(user_id, protect_item.item_id, 1)
            if not ok then
                return false, err
            end
            result = item_model.GEM_RESULT.FAIL
        else
            result = item_model.GEM_RESULT.BREAK
        end
    end
    
    -- 5. 应用卸下结果
    if result == item_model.GEM_RESULT.SUCCESS then
        -- 返还宝石
        local ok, err = M.add_items_to_slot(user_id, {
            {
                item_id = slot.gem_id,
                count = 1
            }
        })
        if not ok then
            return false, err
        end
    end
    
    -- 6. 清空槽位
    equip.gem_slots[slot_index] = {
        state = item_model.GEM_SLOT_STATE.EMPTY
    }
    
    -- 7. 更新装备属性
    local gem_config = ITEM_CONFIG[slot.gem_id]
    if gem_config and gem_config.props then
        for prop_type, value in pairs(gem_config.props) do
            if equip.gem_props then
                equip.gem_props[prop_type] = (equip.gem_props[prop_type] or 0) - value
                if equip.gem_props[prop_type] <= 0 then
                    equip.gem_props[prop_type] = nil
                end
            end
        end
    end
    
    -- 8. 保存更新
    local ok = item_dao.update_user_items(user_id, items)
    if not ok then
        return false, "保存装备失败"
    end
    
    -- 9. 更新属性
    property_service.recalc_equip_props(user_id)
    
    return true, {
        result = result,
        equip = equip
    }
end

-- 获取用户所有背包信息
function M.get_user_bags(user_id)
    if not user_id then
        return nil, "无效的用户ID"
    end

    -- 获取用户所有背包
    local bags = bag_dao.get_user_all_bags(user_id)
    if not bags then
        return nil, "获取背包失败"
    end

    -- 获取用户所有物品
    local items = M.get_user_items(user_id)
    if not items then
        items = {}
    end

    -- 构造返回的背包信息列表
    local bag_info_list = {}
    for _, bag in ipairs(bags) do
        -- 获取该背包中的物品
        local bag_items = {}
        for _, item in ipairs(items) do
            if item.bag_type == bag.bag_type then
                -- 确保所有字段都是数值类型
                local item_info = {
                    item_id = tonumber(item.item_id),
                    count = tonumber(item.count),
                    slot = tonumber(item.slot_index or 0)  -- 确保有默认值
                }
                table.insert(bag_items, item_info)
            end
        end

        -- 构造背包信息
        local bag_info = {
            bag_type = tonumber(bag.bag_type),
            size = tonumber(bag.size),
            items = bag_items
        }
        
        table.insert(bag_info_list, bag_info)
    end

    return bag_info_list
end

return M 