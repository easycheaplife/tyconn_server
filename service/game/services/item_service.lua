local skynet = require "skynet"
local logger = require "logger"
local pb = require "pb"
local item_model = require "models.item_model"
local item_dao = require "dao.item_dao"
local user_service = require "services.user_service"
local snowflake = require "utils.snowflake"

local M = {}

-- 物品配置
local ITEM_CONFIG = {
    [1001] = {  -- 初级经验药水
        effect_type = item_model.EFFECT_TYPE.EXP,
        effect_value = 100
    },
    [2001] = {  -- 金币
        effect_type = item_model.EFFECT_TYPE.GOLD,
        effect_value = 1000
    }
}

-- 新手默认物品
local DEFAULT_ITEMS = {
    {
        item_id = 1001,  -- 初级经验药水
        count = 100
    },
    {
        item_id = 2001,  -- 金币
        count = 1000
    }
}

-- 应用物品效果
local function apply_item_effect(user_id, item_id, count)
    logger.debug("Applying item effect - user_id: %d, item_id: %d, count: %d", 
        user_id, item_id, count)
    local config = ITEM_CONFIG[item_id]
    if not config then
        return false, "物品配置不存在"
    end
    
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

-- 添加物品
function M.add_items(user_id, items)
    if not user_id or not items then
        return false, "参数无效"
    end

    -- 1. 获取当前物品
    local current_items = item_dao.get_user_items(user_id) or {}
    
    -- 2. 合并物品
    for _, item in ipairs(items) do
        local found = false
        for _, curr_item in ipairs(current_items) do
            if curr_item.item_id == item.item_id then
                -- 记录变更前数量
                local before_count = curr_item.count
                curr_item.count = curr_item.count + (item.count or 1)
                curr_item.update_time = os.time()
                
                -- 记录物品变化
                item_dao.log_change(user_id, item.item_id, item.count, 
                    item_model.CHANGE_TYPE.ADD, item_model.CHANGE_SOURCE.REWARD,
                    before_count, curr_item.count)
                found = true
                break
            end
        end
        
        if not found then
            -- 新增物品
            local new_item = item_model.new({
                id = snowflake.generate(),
                user_id = user_id,
                item_id = item.item_id,
                count = item.count or 1
            })
            table.insert(current_items, new_item)
            
            -- 记录物品变化
            item_dao.log_change(user_id, item.item_id, new_item.count,
                item_model.CHANGE_TYPE.ADD, item_model.CHANGE_SOURCE.REWARD,
                0, new_item.count)
        end
    end

    -- 3. 更新数据库和缓存
    return item_dao.update_user_items(user_id, current_items)
end

-- 使用物品
function M.use_item(user_id, item_id, count)
    if not user_id or not item_id or not count or count <= 0 then
        return false, pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_PARAM")
    end

    -- 1. 获取物品
    local items = item_dao.get_user_items(user_id)
    if not items then
        return false, pb.enum("common.ErrorCode", "ERROR_CODE_ITEM_NOT_FOUND")
    end

    -- 2. 查找并使用物品
    for i, item in ipairs(items) do
        if item.item_id == item_id then
            -- 检查物品数量是否足够
            if item.count < count then
                logger.error("物品数量不足 - user_id: %d, item_id: %d, count: %d, have: %d", 
                    user_id, item_id, count, item.count)
                return false, pb.enum("common.ErrorCode", "ERROR_CODE_ITEM_NOT_ENOUGH")
            end

            -- 应用物品效果
            local ok, err = apply_item_effect(user_id, item_id, count)
            if not ok then
                return false, err
            end

            -- 记录变更前数量
            local before_count = item.count
            
            -- 更新数量
            item.count = item.count - count
            item.update_time = os.time()
            
            -- 记录物品变化
            item_dao.log_change(user_id, item_id, count,
                item_model.CHANGE_TYPE.USE, item_model.CHANGE_SOURCE.USE,
                before_count, item.count)

            -- 如果物品数量为0，从列表中删除
            if item.count <= 0 then
                table.remove(items, i)
            end

            -- 更新数据库和缓存
            local ok = item_dao.update_user_items(user_id, items)
            if not ok then
                return false, pb.enum("common.ErrorCode", "ERROR_CODE_DB_ERROR")
            end

            -- 返回变化的物品列表
            return true, {item}
        end
    end

    return false, pb.enum("common.ErrorCode", "ERROR_CODE_ITEM_NOT_FOUND")
end

-- 初始化新用户物品
function M.init_user_items(user_id)
    if not user_id then
        return false, "无效的用户ID"
    end

    logger.info("Initializing items for new user: %d", user_id)
    
    -- 添加默认物品
    local ok = M.add_items(user_id, DEFAULT_ITEMS)
    if not ok then
        logger.error("Failed to add default items for user: %d", user_id)
        return false, "添加默认物品失败"
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

    return items
end

return M 