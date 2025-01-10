local skynet = require "skynet"
local db = require "simpledb"
local pb = require "pb"

local M = {}
local db_id  -- 保存数据库连接ID

-- 初始化数据库连接
function M.init()
    db_id = db.connect({})
    return db_id ~= nil
end

-- 创建用户信息
function M.create_user_info(username, password, nickname)
    return {
        user_id = nil,              -- 将由 create_user 设置
        username = username,
        password = password,
        nickname = nickname or username,
        level = 1,
        exp = 0,
        vip_level = 0,
        gold = 1000,
        diamond = 100,
        avatar = "default.png",
        register_time = os.time(),
        last_login = os.time()
    }
end

-- 创建新用户
function M.create_user(username, password, nickname, avatar)
    -- 检查用户名是否已存在
    local exists = db.get(db_id, "user:" .. username)
    if exists then
        return nil, "用户名已存在"
    end
    
    -- 创建用户信息
    local user = M.create_user_info(username, password, nickname)
    
    -- 生成用户ID
    user.user_id = db.incr(db_id, "next_user_id")
    user.avatar = avatar or "default.png"
    
    -- 保存用户数据
    db.set(db_id, "user:" .. username, user)
    db.set(db_id, "user_id:" .. user.user_id, user)
    
    return user
end

-- 根据用户名获取用户
function M.get_user_by_username(username)
    return db.get(db_id, "user:" .. username)
end

-- 根据用户ID获取用户
function M.get_user_by_id(user_id)
    return db.get(db_id, "user_id:" .. user_id)
end

-- 创建错误响应
function M.create_error_response(code, message)
    return pb.encode("command.S2CRegisterResponse", {
        code = code,
        message = message
    })
end

-- 验证用户名密码
function M.validate_user(username, password)
    local user = M.get_user_by_username(username)
    if not user then
        return nil, "用户不存在"
    end
    
    if user.password ~= password then
        return nil, "密码错误"
    end
    
    return user
end

-- 用户会话管理
local users = {}

-- 添加用户会话
function M.add_user(client_id, user_info)
    users[client_id] = {
        user_info = user_info
    }
end

-- 获取用户会话
function M.get_user(client_id)
    return users[client_id]
end

-- 删除用户会话
function M.remove_user(client_id)
    users[client_id] = nil
end

-- 获取用户统计信息
function M.get_stats()
    -- 使用 db.dump 来获取数据库内容
    local db_content = db.dump(db_id)
    if not db_content then
        return {
            total_users = 0,
            online_users = 0,
            recent_users = {}
        }
    end
    
    -- 统计在线用户
    local online_count = 0
    for _ in pairs(users) do
        online_count = online_count + 1
    end
    
    -- 获取所有用户
    local all_users = {}
    local keys = db.keys(db_id, "^user:")
    for _, key in ipairs(keys) do
        local user = db.get(db_id, key)
        if user then
            table.insert(all_users, user)
        end
    end
    
    -- 按注册时间排序，获取最近注册的用户（最多10个）
    table.sort(all_users, function(a, b)
        return (a.register_time or 0) > (b.register_time or 0)
    end)
    
    local recent_users = {}
    for i = 1, math.min(10, #all_users) do
        table.insert(recent_users, all_users[i])
    end
    
    return {
        total_users = #all_users,
        online_users = online_count,
        recent_users = recent_users
    }
end

-- 更新用户信息
function M.update_user(user)
    if not user or not user.username then
        return false
    end
    
    -- 更新用户数据
    db.set(db_id, "user:" .. user.username, user)
    db.set(db_id, "user_id:" .. user.user_id, user)
    return true
end

return M 