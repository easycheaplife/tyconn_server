local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"

local M = {}

-- 创建用户表
M.CREATE_USERS_TABLE = [[
    CREATE TABLE IF NOT EXISTS users (
        user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
        account VARCHAR(64) NOT NULL,
        username VARCHAR(32) NOT NULL,
        name VARCHAR(32),
        level INT DEFAULT 1,
        gender INT,
        job INT,
        exp BIGINT DEFAULT 0,
        create_time BIGINT,
        last_login_time BIGINT,
        INDEX idx_account (account),
        INDEX idx_name (name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

-- 创建token表
M.CREATE_TOKENS_TABLE = [[
    CREATE TABLE IF NOT EXISTS user_tokens (
        token_id BIGINT PRIMARY KEY AUTO_INCREMENT,
        account VARCHAR(64) NOT NULL,
        token MEDIUMTEXT NOT NULL,
        expire_time BIGINT NOT NULL,
        device_id VARCHAR(64),
        platform VARCHAR(32),
        create_time BIGINT NOT NULL,
        INDEX idx_account (account),
        INDEX idx_expire_time (expire_time)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

-- 用户相关SQL
M.CHECK_USER_EXISTS = [[
    SELECT user_id FROM users 
    WHERE username = '%s' 
    LIMIT 1
]]

M.CREATE_USER = [[
    INSERT INTO users (
        account, username, name, gender, 
        job, level, exp, create_time
    ) VALUES (
        '%s', '%s', '%s', %d, 
        %d, %d, %d, %d
    )
]]

M.GET_USER_BY_ACCOUNT = [[
    SELECT * FROM users 
    WHERE account = '%s' 
    LIMIT 1
]]

M.UPDATE_USER = [[
    UPDATE users SET 
        name = '%s',
        level = %d,
        exp = %d,
        job = %d,
        gender = %d,
        last_login_time = %d
    WHERE account = '%s'
]]

-- Token相关SQL
M.SYNC_TOKEN = [[
    INSERT INTO user_tokens (
        account, token, device_id, platform, 
        expire_time, create_time
    ) VALUES (
        '%s', '%s', '%s', '%s', 
        %d, %d
    )
]]

M.DELETE_OLD_TOKENS = [[
    DELETE FROM user_tokens 
    WHERE account = '%s'
]]

M.GET_TOKEN = [[
    SELECT * FROM user_tokens 
    WHERE account = '%s' AND token = '%s'
    LIMIT 1
]]

M.CLEAN_EXPIRED_TOKENS = [[
    DELETE FROM user_tokens 
    WHERE expire_time < %d
]]

-- 初始化数据库
function M.init()
    -- 创建用户表
    local ok, err = pcall(mysql.query, M.CREATE_USERS_TABLE)
    if not ok then
        logger.error("Failed to create users table: %s", err)
        return false
    end
    
    -- 创建token表
    ok, err = pcall(mysql.query, M.CREATE_TOKENS_TABLE)
    if not ok then
        logger.error("Failed to create tokens table: %s", err)
        return false
    end
    
    logger.info("Database tables initialized successfully")
    return true
end

return M 