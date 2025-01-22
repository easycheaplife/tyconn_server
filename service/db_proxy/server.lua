local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local db_init = require "db_proxy.init"

local CMD = {}

-- 打印 SQL 语句
local function log_sql(sql, ...)
    if ... then
        local args = {...}
        for i, arg in ipairs(args) do
            if type(arg) == "string" then
                arg = string.format("'%s'", arg)
            end
            args[i] = tostring(arg)
        end
        sql = string.format(sql, table.unpack(args))
    end
    logger.debug("[SQL] %s", sql)
end

-- 初始化数据库连接
local function init_db()
    if not db_init.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    return true
end

-- 根据用户名获取用户
function CMD.get_user_by_username(username)
    local sql = "SELECT * FROM users WHERE username = '%s' LIMIT 1"
    log_sql(sql, username)
    return mysql.query("SELECT * FROM users WHERE username = '%s' LIMIT 1", username)
end

-- 根据用户ID获取用户
function CMD.get_user_by_id(user_id)
    local sql = "SELECT * FROM users WHERE user_id = %d LIMIT 1"
    log_sql(sql, user_id)
    return mysql.query("SELECT * FROM users WHERE user_id = %d LIMIT 1", user_id)
end

-- 创建新用户
function CMD.create_user(user_info)
    -- 开始事务
    log_sql("START TRANSACTION")
    if not mysql.begin() then
        return nil, "系统错误"
    end
    
    -- 插入用户数据
    local sql = [[
        INSERT INTO users (
            username, password, nickname, avatar, 
            register_time, last_login
        ) VALUES (
            '%s', '%s', '%s', '%s', %d, %d
        )
    ]]
    log_sql(sql, 
        user_info.username,
        user_info.password,
        user_info.nickname,
        user_info.avatar,
        user_info.register_time,
        user_info.last_login
    )
    
    local res = mysql.query(sql,
        user_info.username,
        user_info.password,
        user_info.nickname,
        user_info.avatar,
        user_info.register_time,
        user_info.last_login
    )
    
    if not res or not res.insert_id then
        mysql.rollback()
        log_sql("ROLLBACK")
        return nil, "创建用户失败"
    end
    
    -- 获取创建的用户信息
    sql = "SELECT * FROM users WHERE user_id = %d"
    log_sql(sql, res.insert_id)
    local users = mysql.query(sql, res.insert_id)
    if not users or not users[1] then
        mysql.rollback()
        log_sql("ROLLBACK")
        return nil, "获取用户信息失败"
    end
    
    -- 提交事务
    log_sql("COMMIT")
    if not mysql.commit() then
        mysql.rollback()
        log_sql("ROLLBACK")
        return nil, "系统错误"
    end
    
    return users[1]
end

-- 更新用户信息
function CMD.update_user(user)
    if not user or not user.user_id then
        return false, "无效的用户信息"
    end
    
    local sql = [[
        UPDATE users SET 
            nickname = '%s',
            level = %d,
            exp = %d,
            vip_level = %d,
            gold = %d,
            diamond = %d,
            avatar = '%s',
            last_login = %d
        WHERE user_id = %d
    ]]
    log_sql(sql,
        user.nickname,
        user.level,
        user.exp,
        user.vip_level,
        user.gold,
        user.diamond,
        user.avatar,
        user.last_login,
        user.user_id
    )
    
    local res = mysql.query(sql,
        user.nickname,
        user.level,
        user.exp,
        user.vip_level,
        user.gold,
        user.diamond,
        user.avatar,
        user.last_login,
        user.user_id
    )
    
    return res and res.affected_rows > 0
end

-- 获取总用户数
function CMD.get_total_users()
    log_sql("SELECT COUNT(*) as count FROM users")
    local res = mysql.query("SELECT COUNT(*) as count FROM users")
    return res and res[1] and res[1].count or 0
end

-- 获取最近注册的用户
function CMD.get_recent_users()
    local sql = [[
        SELECT * FROM users 
        ORDER BY register_time DESC 
        LIMIT 10
    ]]
    log_sql(sql)
    return mysql.query(sql) or {}
end

-- 获取在线用户数
function CMD.get_online_count()
    local sql = [[
        SELECT COUNT(*) as count FROM users 
        WHERE last_login > ? AND last_login + 300 > ?
    ]]
    log_sql(sql, os.time() - 300, os.time())
    return mysql.query(sql, os.time() - 300, os.time()) or 0
end

-- 同步JWT令牌
function CMD.sync_jwt(token_info)
    -- 验证参数
    if not token_info.token or not token_info.user_id or not token_info.username then
        logger.error("Invalid token info: missing required fields")
        return false
    end
    
    -- 更新或插入token记录
    local sql = string.format(
        "INSERT INTO user_tokens (user_id, username, token, expire_time) " ..
        "VALUES (%d, '%s', '%s', FROM_UNIXTIME(%d)) " ..
        "ON DUPLICATE KEY UPDATE token='%s', expire_time=FROM_UNIXTIME(%d)",
        token_info.user_id,
        mysql.escape(token_info.username),
        mysql.escape(token_info.token),
        token_info.expire_time,
        mysql.escape(token_info.token),
        token_info.expire_time
    )
    
    local ok = mysql.query(sql)
    if not ok then
        logger.error("Failed to sync JWT token for user %d", token_info.user_id)
        return false
    end
    
    logger.debug("JWT token synced for user %d", token_info.user_id)
    return true
end

-- 验证JWT令牌
function CMD.verify_jwt(token)
    if not token then
        return false
    end
    
    local sql = string.format(
        "SELECT user_id, username FROM user_tokens " ..
        "WHERE token='%s' AND expire_time > NOW()",
        mysql.quote_sql_str(token)
    )
    
    local result = mysql.query(sql)
    if not result or #result == 0 then
        return false
    end
    
    return result[1]
end

-- 验证账号
function CMD.verify_account(account, password)
    logger.debug("Verifying account: %s", account)
    
    -- 查询用户
    local sql = string.format(
        "SELECT * FROM users WHERE account = '%s' LIMIT 1",
        mysql.escape(account)
    )
    
    local users = mysql.query(sql)
    if not users or #users == 0 then
        -- 创建新用户
        logger.info("Creating new user: %s", account)
        local now = os.time()
        sql = string.format(
            "INSERT INTO users (account, password, username, create_time, login_time) " ..
            "VALUES ('%s', '%s', '%s', %d, %d)",
            mysql.escape(account),
            mysql.escape(password),
            mysql.escape(account),
            now,
            now
        )
        
        local ok = mysql.query(sql)
        if not ok then
            logger.error("Failed to create user: %s", account)
            return nil
        end
        
        -- 获取新创建的用户
        sql = string.format(
            "SELECT * FROM users WHERE account = '%s' LIMIT 1",
            mysql.escape(account)
        )
        users = mysql.query(sql)
    end
    
    local user = users[1]
    if user.password ~= password then
        logger.warn("Wrong password for account: %s", account)
        return nil
    end
    
    -- 更新登录时间
    sql = string.format(
        "UPDATE users SET login_time = %d WHERE user_id = %d",
        os.time(),
        user.user_id
    )
    mysql.query(sql)
    
    logger.info("Account verified: %s (ID: %d)", account, user.user_id)
    return user
end

-- 获取用户信息
function CMD.get_user(user_id)
    local sql = string.format(
        "SELECT * FROM users WHERE user_id = %d LIMIT 1",
        user_id
    )
    
    local ok, results = pcall(mysql.query, sql)
    if not ok then
        logger.error("Failed to get user: %s", results)
        return nil
    end
    
    if #results == 0 then
        return nil
    end
    
    return results[1]
end

-- 检查角色名是否存在
function CMD.check_name_exists(name)
    local sql = string.format(
        "SELECT 1 FROM users WHERE name = '%s' LIMIT 1",
        mysql.escape(name)
    )
    
    local ok, results = pcall(mysql.query, sql)
    if not ok then
        logger.error("Failed to check name: %s", results)
        return true  -- 出错时返回存在，防止重名
    end
    
    return #results > 0
end

-- 更新用户信息
function CMD.update_user(user_info)
    local fields = {}
    for k, v in pairs(user_info) do
        if k ~= "user_id" then
            if type(v) == "string" then
                table.insert(fields, string.format("%s = '%s'", k, mysql.escape(v)))
            else
                table.insert(fields, string.format("%s = %s", k, tostring(v)))
            end
        end
    end
    
    local sql = string.format(
        "UPDATE users SET %s WHERE user_id = %d",
        table.concat(fields, ", "),
        user_info.user_id
    )
    
    local ok, res = pcall(mysql.query, sql)
    if not ok then
        logger.error("Failed to update user: %s", res)
        return nil
    end
    
    return CMD.get_user(user_info.user_id)
end

-- 同步token
function CMD.sync_token(token_info)
    logger.debug("Syncing token for user: %d", token_info.user_id)
    
    -- 删除旧token
    local sql = string.format(
        "DELETE FROM user_tokens WHERE user_id = %d",
        token_info.user_id
    )
    mysql.query(sql)
    
    -- 插入新token
    sql = string.format(
        "INSERT INTO user_tokens (user_id, token, expire_time, device_id, platform) " ..
        "VALUES (%d, '%s', %d, '%s', '%s')",
        token_info.user_id,
        mysql.escape(token_info.token),
        token_info.expire_time,
        mysql.escape(token_info.device_id or ""),
        mysql.escape(token_info.platform or "")
    )
    
    local ok = mysql.query(sql)
    if not ok then
        logger.error("Failed to sync token for user: %d", token_info.user_id)
        return false
    end
    
    logger.info("Token synced for user: %d", token_info.user_id)
    return true
end

-- 服务入口
skynet.start(function()
    logger.info("DB proxy starting...")
    
    -- 初始化数据库
    if not init_db() then
        logger.error("Failed to initialize database")
        return
    end
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = CMD[command]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", command)
        end
    end)
    
    logger.info("DB proxy started")
end) 