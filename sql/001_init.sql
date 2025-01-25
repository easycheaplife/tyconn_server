-- 版本表
CREATE TABLE IF NOT EXISTS db_version (
    version INT PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 初始版本
INSERT INTO db_version (version) VALUES (1);

-- 用户表
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户令牌表
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; 