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
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,          -- 用户ID
    card_id INT NOT NULL,             -- 卡牌ID
    level INT UNSIGNED NOT NULL DEFAULT 1,
    exp INT UNSIGNED NOT NULL DEFAULT 0,
    star INT UNSIGNED NOT NULL DEFAULT 1,
    quality INT UNSIGNED NOT NULL DEFAULT 1,
    power INT UNSIGNED NOT NULL DEFAULT 0,
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL,
    INDEX idx_user_card (user_id, card_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户物品表
CREATE TABLE IF NOT EXISTS user_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,          -- 用户ID
    item_id INT NOT NULL,             -- 物品ID
    count INT NOT NULL DEFAULT 1,      -- 数量
    create_time BIGINT NOT NULL,       -- 获得时间
    update_time BIGINT NOT NULL,       -- 更新时间
    INDEX idx_user_item (user_id, item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 物品变化日志表
CREATE TABLE IF NOT EXISTS item_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,          -- 用户ID
    item_id INT NOT NULL,             -- 物品ID
    count INT NOT NULL,               -- 变化数量
    type TINYINT NOT NULL,            -- 变化类型
    source VARCHAR(32) NOT NULL,       -- 来源
    before_count INT NOT NULL,         -- 变化前数量
    after_count INT NOT NULL,          -- 变化后数量
    create_time BIGINT NOT NULL,       -- 记录时间
    INDEX idx_user_time (user_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; 