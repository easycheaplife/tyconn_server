local skynet = require "skynet"
local logger = require "logger"
local utils = require "utils"
local user_model = require "models.user_model"
local user_dao = require "dao.user_dao"
local property_service = require "services.property_service"
local cache = require "cache"

local M = {}
local default_unit_id = 10001

-- 初始化
function M.init()
    return true
end

-- 创建用户信息
function M.create_user_info(username, password, nickname)
    local now = os.time()
    return {
        username = username,
        password = password,
        nickname = nickname or username,
        avatar = "default.png",
        level = 1,
        exp = 0,
        vip_level = 0,
        gold = 1000,
        diamond = 100,
        register_time = now,
        last_login = now,
    }
end

-- 创建新用户
function M.create_user(username, password, nickname, avatar)
    -- 检查用户名是否已存在
    local exists = user_dao.get_user_by_username(username)
    if exists then
        return nil, "用户名已存在"
    end
    
    -- 创建用户信息
    local user = M.create_user_info(username, password, nickname)
    user.avatar = avatar or "default.png"
    user.unit_id = default_unit_id
    logger.debug("create_user: %s", utils.table_to_string(user))
    
    -- 使用 dao 创建用户
    local ok, created_user = user_dao.create_user(user)
    if not ok then
        return nil, "创建用户失败"
    end
    
    -- 写入缓存
    M.cache_user_by_id(created_user)
    M.cache_user_by_account(created_user)
    
    return created_user
end

-- 获取或创建用户
function M.get_or_create_user(account, username)
    -- 1. 尝试获取用户
    local user = M.get_user(account)
    if user then
        -- 写入缓存
        M.cache_user_by_id(user)
        M.cache_user_by_account(user)
        return user, nil, false
    end

    -- 2. 创建新用户
    logger.debug("Creating new user for account: %s", account)
    local user_data = user_model.new({
        account = account,
        username = username,
    })

    local success, created_user = user_dao.create_user(user_data)
    if not success then
        return nil, created_user -- created_user 此时是错误信息
    end
    logger.debug("created_user: %s", utils.table_to_string(created_user))
    -- 写入缓存
    M.cache_user_by_id(created_user)
    M.cache_user_by_account(created_user)

    logger.info("New user created: %s (ID: %d)", account, created_user.user_id)
    return created_user, nil, true
end

-- 增加经验
function M.add_exp(user_id, exp)
    logger.debug("Adding exp to user %d: %d", user_id, exp)
    if not user_id or not exp or exp <= 0 then
        return false, "参数无效"
    end

    -- 从缓存获取用户信息
    local user_info = cache.get_user_info(user_id)
    if not user_info then
        return false, "用户不存在"
    end

    -- 确保经验值存在
    user_info.exp = (user_info.exp or 0) + exp
    -- 检查是否升级
    local old_level = user_info.level
    local new_level = M.calculate_level(user_info.exp)
    if new_level > old_level then
        user_info.level = new_level
        -- 更新属性
        user_info = M.update_user_property(user_info)
    end
    -- 更新数据库和缓存
    local ok = user_dao.update_user(user_info)
    if ok then
        M.cache_user(user_info)
    end
    return true
end

-- 更新用户属性
function M.update_user_property(user_info)
    local property = property_service.get_unit_property(default_unit_id, user_info.level)
    if property then
        -- 更新属性
        user_info.hp = property.hp
        user_info.attack = property.attack
        user_info.defense = property.defense
        
        -- 更新数据库和缓存
        local ok = user_dao.update_user(user_info)
        if ok then
            M.cache_user(user_info)
        end
    end
    return user_info
end

-- 增加金币
function M.add_gold(user_id, gold)
    logger.debug("Adding gold to user %d: %d", user_id, gold)
    if not user_id or not gold or gold <= 0 then
        return false, "参数无效"
    end

    local user_info = cache.get_user_info(user_id)
    if not user_info then
        return false, "用户不存在"
    end

    -- 确保金币值存在
    user_info.gold = (user_info.gold or 0) + gold
    
    -- 更新数据库和缓存
    local ok = user_dao.update_user(user_info)
    if ok then
        M.cache_user(user_info)
    end
    return true
end

-- 计算等级
function M.calculate_level(exp)
    return math.floor(exp / 1000) + 1
end

-- 获取用户信息
function M.get_user(account)
    logger.debug("Getting user info for account: %s", account)
    if not account then
        return nil
    end

    -- 1. 从缓存获取
    local user = M.get_user_from_cache(account)
    if user then
        logger.debug("Got user from cache: %s, user_id: %s", account, user.user_id)
        return user
    end

    -- 2. 从数据库获取
    local result = user_dao.get_user(account)
    if not result then
        logger.error("Failed to get user from db: %s", account)
        return nil
    end

    logger.debug("Got user from db: %s, user_id: %s", account, result.user_id)
    -- 3. 写入缓存
    M.cache_user_by_id(result)
    M.cache_user_by_account(result)  -- 同时缓存 account 到 user_id 的映射

    return result
end

-- 从缓存获取用户信息
function M.get_user_from_cache(account)
    logger.debug("Getting user from cache: %s", account)
    -- 先获取user_id
    local user_id = cache.get_user_id_by_account(account)
    if not user_id then
        return nil
    end
    -- 再获取用户信息
    local user = cache.get_user_info(user_id)
    if user then
        logger.debug("Got user from cache: %s", account)
        return user
    end
    return nil
end

-- 缓存用户信息(通过user_id)
function M.cache_user_by_id(user)
    if not user or not user.user_id then
        logger.error("Failed to cache user: invalid user data")
        return false
    end
    
    logger.debug("Caching user info by ID: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))
    return M.cache_user(user)
end

-- 缓存用户信息(通过account)
function M.cache_user_by_account(user)
    if not user or not user.account then
        logger.error("Failed to cache user: invalid user data")
        return false
    end
    
    logger.debug("Caching user info by account: %s", utils.table_to_string({
        account = user.account,
        user_id = user.user_id,
        username = user.username
    }))

    return cache.set_account_mapping(user.account, user.user_id)
end

-- 将用户信息存入缓存
function M.cache_user(user_info)
    logger.info("Caching user info: %s", utils.table_to_string(user_info))
    if not user_info or not user_info.user_id then
        return false, "Invalid user info"
    end
    local base_property = property_service.get_unit_property(default_unit_id, user_info.level)
    -- 添加基础属性
    user_info.hp = base_property and base_property.hp or 0
    user_info.attack = base_property and base_property.attack or 0
    user_info.defense = base_property and base_property.defense or 0
    
    logger.debug("Caching user info: %s", utils.table_to_string({
        account = user_info.account,
        user_id = user_info.user_id,
        username = user_info.username,
        hp = user_info.hp,
        attack = user_info.attack,
        defense = user_info.defense
    }))

    return cache.set_user_info(user_info.user_id, user_info)
end

-- 根据用户ID获取用户
function M.get_user_by_id(user_id)
    -- 1. 先从缓存获取
    local user = cache.get_user_info(user_id)
    if user then
        logger.debug("Got user from cache by ID: %d", user_id)
        return user
    end

    -- 2. 从数据库获取
    local user = user_dao.get_user_by_id(user_id)
    if not user then
        logger.error("Failed to get user from db by ID: %d", user_id)
        return nil
    end

    -- 3. 写入缓存
    M.cache_user_by_id(user)
    
    logger.debug("Got user from db by ID: %d", user_id)
    return user
end

-- 根据用户名获取用户
function M.get_user_by_username(username)
    local user = user_dao.get_user_by_username(username)
    if user then
        -- 确保时间戳是数字
        user.register_time = tonumber(user.register_time) or os.time()
        user.last_login = tonumber(user.last_login) or os.time()
    end
    return user
end

-- 获取用户统计信息
function M.get_stats()
    return user_dao.get_stats()
end

function M.check_gm_permission(user_id)
    return true
end
return M 