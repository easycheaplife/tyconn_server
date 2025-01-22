local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"

local M = {}

-- 创建用户表
local function create_users_table()
    local sql = [[
        CREATE TABLE IF NOT EXISTS users (
            user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
            account VARCHAR(64) NOT NULL UNIQUE,
            password VARCHAR(64) NOT NULL,
            username VARCHAR(32) NOT NULL,
            name VARCHAR(32),
            level INT DEFAULT 1,
            gender INT,
            job INT,
            exp BIGINT DEFAULT 0,
            vip_level INT DEFAULT 0,
            create_time BIGINT,
            login_time BIGINT,
            INDEX idx_account (account),
            INDEX idx_name (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]
    
    return mysql.query(sql)
end

-- 创建token表
local function create_tokens_table()
    local sql = [[
        CREATE TABLE IF NOT EXISTS user_tokens (
            token_id BIGINT PRIMARY KEY AUTO_INCREMENT,
            user_id BIGINT NOT NULL,
            token TEXT NOT NULL,
            expire_time BIGINT NOT NULL,
            device_id VARCHAR(64),
            platform VARCHAR(32),
            create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_user_id (user_id),
            INDEX idx_expire_time (expire_time)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]
    
    return mysql.query(sql)
end

-- 初始化数据库
function M.init()
    -- 初始化MySQL连接
    if not mysql.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    
    -- 创建用户表
    if not create_users_table() then
        logger.error("Failed to create users table")
        return false
    end
    
    -- 创建token表
    if not create_tokens_table() then
        logger.error("Failed to create tokens table")
        return false
    end
    
    logger.info("Database initialized successfully")
    return true
end

return M 