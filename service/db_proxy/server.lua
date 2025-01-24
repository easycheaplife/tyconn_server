local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"
local user_model = require "db_proxy.models.user"
local sql = require "db_proxy.sql.user"

local CMD = {}

-- 打印 SQL 语句
local function log_sql(sql, params)
    local sql_str = "[SQL] " .. sql
    if params then
        sql_str = sql_str .. " [" .. table.concat(params, ", ") .. "]"
    end
    logger.debug(sql_str)
end

-- 初始化数据库连接
local function init_db()
    if not sql.init() then
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

-- 执行事务
local function transaction(func)
    log_sql("START TRANSACTION")
    local ok, err = pcall(mysql.query, "START TRANSACTION")
    if not ok then
        logger.error("Failed to start transaction: %s", err)
        return false, err
    end
    
    local result, err = func()
    if not result then
        log_sql("ROLLBACK")
        mysql.query("ROLLBACK")
        return false, err
    end
    
    log_sql("COMMIT")
    mysql.query("COMMIT")
    return true
end

-- 创建新用户
function CMD.create_user(user)
    return user_model.create_user(user)
end

-- 更新用户信息
function CMD.update_user(user)
    return user_model.update_user(user)
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
    logger.debug("Saving token for user: %s", token_info.account)
    
    return transaction(function()
        -- 删除该用户的旧token（通过account查找）
        local sql = string.format(
            "DELETE FROM user_tokens WHERE account = '%s'",
            mysql.escape(token_info.account)
        )
        log_sql(sql)
        
        local ok, err = pcall(mysql.query, sql)
        if not ok then
            logger.error("Failed to delete old tokens: %s", err)
            return false, "Database error"
        end
        
        -- 插入新token
        sql = string.format(
            "INSERT INTO user_tokens (account, token, device_id, platform, expire_time, create_time) " ..
            "VALUES ('%s', '%s', '%s', '%s', %d, %d)",
            mysql.escape(token_info.account),
            mysql.escape(token_info.token),
            mysql.escape(token_info.device_id or ''),
            mysql.escape(token_info.platform or ''),
            token_info.expire_time,
            token_info.create_time
        )
        log_sql(sql)
        
        ok, err = pcall(mysql.query, sql)
        if not ok then
            logger.error("Failed to insert token: %s", err)
            return false, "Database error"
        end
        
        return true
    end)
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
function CMD.get_user(account)
    return user_model.get_user(account)
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
    logger.info("DB proxy server starting...")
    
    -- 初始化数据库
    if not init_db() then
        logger.error("Failed to initialize database")
        return
    end
    
    -- 注册消息处理器
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = CMD[command]
        if f then
            logger.debug("Handling command: %s", command)
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", command)
        end
    end)
    
    logger.info("DB proxy server started")
end) 