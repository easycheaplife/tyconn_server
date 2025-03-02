local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "logger"
local utils = require "utils"
local service_balancer = require "service_balancer"

local M = {}

-- 调用数据库服务
local function call_db(...)
    -- 从balancer获取db_proxy节点
    local node = service_balancer.get_node("db_proxy", skynet.getenv("node_name"))
    -- 使用 @node 作为服务名，因为是跨节点调用
    return cluster.call(node, "@"..node, ...)
end

-- 批量创建卡牌
function M.batch_create_cards(cards)
    return call_db("batch_create_cards", cards)
end

-- 获取用户卡牌列表
function M.get_user_cards(user_id)
    if not user_id then
        logger.error("get_user_cards: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_user_cards", user_id)
    if not ok then
        logger.error("Failed to get user cards: %s", result)
        return nil
    end
    
    return result
end

-- 更新卡牌信息
function M.update_card(card)
    return call_db("update_card", card)
end

-- 获取用户信息
function M.get_user(account)
    return call_db("get_user", account)
end

-- 创建用户
function M.create_user(user)
    return call_db("create_user", user)
end

-- 获取用户物品
function M.get_user_items(user_id)
    return call_db("get_user_items", user_id)
end

-- 更新用户物品
function M.update_user_items(user_id, items)
    return call_db("update_user_items", user_id, items)
end

-- 记录物品变化
function M.log_item_change(user_id, item_id, count, type, source, before_count, after_count)
    -- 添加参数检查
    if not user_id then
        logger.error("log_item_change: missing user_id")
        return false
    end
    if not item_id then
        logger.error("log_item_change: missing item_id")
        return false
    end
    if not count then
        logger.error("log_item_change: missing count")
        return false
    end
    if not type then
        logger.error("log_item_change: missing type")
        return false
    end
    if not source then
        logger.error("log_item_change: missing source")
        return false
    end
    
    return call_db("log_item_change", {
        user_id = user_id,
        item_id = item_id,
        count = count,
        type = type,
        source = source or "unknown",  -- 提供默认值
        before_count = before_count or 0,  -- 提供默认值
        after_count = after_count or 0,    -- 提供默认值
        create_time = os.time()
    })
end

-- 更新用户信息
function M.update_user(user_info)
    if not user_info or not user_info.user_id then
        logger.error("update_user: invalid user info")
        return nil
    end

    local ok, result = pcall(call_db, "update_user", user_info)
    if not ok then
        logger.error("Failed to update user: %s, error: %s", 
            utils.table_to_string(user_info), result)
        return nil
    end

    return result
end

-- 创建卡牌
function M.create_card(card)
    return call_db("create_card", card)
end

-- 获取用户背包
function M.get_user_bag(user_id, bag_type)
    return call_db("get_user_bag", user_id, bag_type)
end

-- 获取用户背包列表
function M.get_user_bags(user_id)
    return call_db("get_user_bags", user_id)
end

-- 获取背包格子状态
function M.get_bag_slots(user_id, bag_type)
    return call_db("get_bag_slots", user_id, bag_type)
end

-- 更新用户背包
function M.update_user_bag(user_id, bag_type, bag_data)
    return call_db("update_user_bag", user_id, bag_type, bag_data)
end

-- 创建用户背包
function M.create_user_bag(params)
    -- 检查参数
    if not params or not params.user_id or not params.bag_type or not params.size then
        logger.error("Invalid params for create_user_bag: %s", utils.table_to_string(params))
        return false
    end

    -- 调用数据库服务
    local ok, result = pcall(call_db, "create_user_bag", params)
    if not ok then
        logger.error("Failed to create user bag: %s", result)
        return false
    end

    return result
end

-- 删除用户背包
function M.delete_user_bag(user_id, bag_type)
    return call_db("delete_user_bag", user_id, bag_type)
end

-- 批量创建格子
function M.batch_create_slots(slots)
    -- 转换格子数据为数据库格式
    local db_slots = {}
    for _, slot in ipairs(slots) do
        table.insert(db_slots, {
            id = slot.id,  -- 使用 snowflake 生成的 ID
            user_id = slot.user_id,
            bag_type = slot.bag_type,
            slot_index = slot.slot_index,
            state = slot.state,
            create_time = os.time(),
            update_time = os.time()
        })
    end
    return call_db("batch_create_slots", db_slots)
end

-- 更新格子状态
function M.update_slot_state(user_id, bag_type, slot_index, state)
    return call_db("update_slot_state", {
        user_id = user_id,
        bag_type = bag_type,
        slot_index = slot_index,
        state = state,
        update_time = os.time()
    })
end

-- 更新背包大小
function M.update_bag_size(user_id, bag_type, new_size)
    -- 检查参数
    if not user_id or not bag_type or not new_size then
        logger.error("update_bag_size: invalid params, user_id: %d, bag_type: %d, new_size: %d",
            user_id, bag_type, new_size)
        return false
    end

    -- 调用数据库服务
    local ok, result = pcall(call_db, "update_bag_size", {
        user_id = user_id,
        bag_type = bag_type,
        size = new_size,
        update_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to update bag size: %s", result)
        return false
    end

    return result
end

-- 检查用户装备槽是否存在
function M.check_equip_slots_exist(user_id)
    if not user_id then
        logger.error("check_equip_slots_exist: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "check_equip_slots_exist", user_id)
    if not ok then
        logger.error("Failed to check equip slots exist: %s", result)
        return nil
    end
    
    return result and result.count
end

-- 获取用户装备槽
function M.get_equip_slots(user_id)
    if not user_id then
        logger.error("get_equip_slots: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_equip_slots", user_id)
    if not ok then
        logger.error("Failed to get equip slots: %s", result)
        return nil
    end
    
    return result
end

-- 获取用户装备等级
function M.get_equip_level(user_id)
    if not user_id then
        logger.error("get_equip_level: user_id is nil")
        return nil
    end
    
    local ok, result = pcall(call_db, "get_equip_level", user_id)
    if not ok then
        logger.error("Failed to get equip level: %s", result)
        return nil
    end
    
    return result and result[1]
end

-- 更新装备槽位
function M.update_equip_slot(user_id, slot_id, item_id, expire_time)
    if not user_id or not slot_id then
        logger.error("update_equip_slot: invalid params, user_id: %s, slot_id: %s", 
            tostring(user_id), tostring(slot_id))
        return false
    end
    
    local ok, result = pcall(call_db, "update_equip_slot", {
        user_id = user_id,
        slot_id = slot_id,
        item_id = item_id,
        expire_time = expire_time or 0,
        equip_time = item_id and os.time() or 0,
        update_time = os.time()
    })
    
    if not ok then
        logger.error("Failed to update equip slot: %s", result)
        return false
    end
    
    return result
end

-- 更新装备等级
function M.update_equip_level(params)
    if not params or not params.user_id then
        logger.error("update_equip_level: missing user_id")
        return false
    end
    
    -- 确保有更新的内容
    if not params.level and not params.is_upgrading and 
       not params.upgrade_start_time and not params.upgrade_end_time then
        logger.error("update_equip_level: no update fields")
        return false
    end
    
    params.update_time = os.time()
    
    local ok, result = pcall(call_db, "update_equip_level", params)
    if not ok then
        logger.error("Failed to update equip level: %s", result)
        return false
    end
    
    return result
end

-- 初始化装备槽
function M.init_equip_slots(user_id, slots)
    if not user_id or not slots or #slots == 0 then
        logger.error("init_equip_slots: invalid params")
        return false
    end
    
    local ok, result = pcall(call_db, "init_equip_slots", {
        user_id = user_id,
        slots = slots
    })
    
    if not ok then
        logger.error("Failed to init equip slots: %s", result)
        return false
    end
    
    return result
end

-- 初始化装备等级
function M.init_equip_level(user_id, level_data)
    if not user_id or not level_data then
        logger.error("init_equip_level: invalid params")
        return false
    end
    
    level_data.user_id = user_id
    level_data.update_time = level_data.update_time or os.time()
    
    local ok, result = pcall(call_db, "init_equip_level", level_data)
    if not ok then
        logger.error("Failed to init equip level: %s", result)
        return false
    end
    
    return result
end

-- 获取已完成的升级
function M.get_completed_equip_upgrades()
    local current_time = os.time()
    
    local ok, result = pcall(call_db, "get_completed_equip_upgrades", current_time)
    if not ok then
        logger.error("Failed to get completed equip upgrades: %s", result)
        return {}
    end
    
    return result or {}
end

-- 获取过期装备
function M.get_expired_equipment(user_id)
    if not user_id then
        logger.error("get_expired_equipment: user_id is nil")
        return {}
    end
    
    local current_time = os.time()
    
    local ok, result = pcall(call_db, "get_expired_equipment", {
        user_id = user_id,
        current_time = current_time
    })
    
    if not ok then
        logger.error("Failed to get expired equipment: %s", result)
        return {}
    end
    
    return result or {}
end

return M 