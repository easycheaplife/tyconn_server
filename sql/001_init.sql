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
    level INT DEFAULT 1,
    exp BIGINT DEFAULT 0,
    vip_level INT DEFAULT 0,
    create_time BIGINT,
    last_login_time BIGINT,
    INDEX idx_account (account),
    INDEX idx_username (username)
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

-- 用户卡牌表
CREATE TABLE IF NOT EXISTS user_cards (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    card_id INT UNSIGNED NOT NULL,
    level INT UNSIGNED NOT NULL DEFAULT 1,
    exp INT UNSIGNED NOT NULL DEFAULT 0,
    star INT UNSIGNED NOT NULL DEFAULT 1,
    quality INT UNSIGNED NOT NULL DEFAULT 1,
    power INT UNSIGNED NOT NULL DEFAULT 0,
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_user_card (user_id, card_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; 