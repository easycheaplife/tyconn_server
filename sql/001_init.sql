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
    id BIGINT PRIMARY KEY,           -- 物品实例ID
    user_id BIGINT NOT NULL,         -- 所属用户ID
    item_id INT NOT NULL,            -- 物品模板ID
    count INT NOT NULL,              -- 数量
    bag_type TINYINT,               -- 所在背包类型
    slot_index INT,                 -- 所在格子索引
    bind_type TINYINT DEFAULT 0,     -- 绑定类型
    expire_time BIGINT DEFAULT 0,    -- 过期时间
    enhance_level INT DEFAULT 0,     -- 强化等级
    refine_level INT DEFAULT 0,      -- 精炼等级
    gem_slots TEXT,                  -- 宝石槽位(JSON)
    props TEXT,                      -- 属性(JSON)
    extra_data TEXT,                 -- 扩展数据(JSON)
    create_time BIGINT NOT NULL,     -- 创建时间
    update_time BIGINT NOT NULL,     -- 更新时间
    INDEX idx_user (user_id),
    INDEX idx_item (item_id),
    INDEX idx_expire (expire_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 物品变化日志表
CREATE TABLE IF NOT EXISTS item_change_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,         -- 用户ID
    item_id INT NOT NULL,            -- 物品ID
    count INT NOT NULL,              -- 变化数量
    type TINYINT NOT NULL,           -- 变化类型
    source VARCHAR(32) NOT NULL,     -- 变化来源
    before_count INT NOT NULL,       -- 变化前数量
    after_count INT NOT NULL,        -- 变化后数量
    time BIGINT NOT NULL,            -- 变化时间
    INDEX idx_user_time (user_id, time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 物品使用记录表
CREATE TABLE IF NOT EXISTS item_use_records (
    user_id BIGINT NOT NULL,         -- 用户ID
    item_id INT NOT NULL,            -- 物品ID
    use_count INT DEFAULT 0,         -- 使用次数
    last_use_time BIGINT DEFAULT 0,  -- 最后使用时间
    reset_time BIGINT DEFAULT 0,     -- 重置时间
    PRIMARY KEY (user_id, item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 物品交易日志表
CREATE TABLE IF NOT EXISTS item_trade_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    from_user BIGINT NOT NULL,       -- 交易发起方
    to_user BIGINT NOT NULL,         -- 交易接收方
    item_id INT NOT NULL,            -- 物品ID
    count INT NOT NULL,              -- 交易数量
    time BIGINT NOT NULL,            -- 交易时间
    INDEX idx_from (from_user, time),
    INDEX idx_to (to_user, time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户背包表
CREATE TABLE IF NOT EXISTS user_bags (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,         -- 用户ID
    bag_type TINYINT NOT NULL,       -- 背包类型
    size INT NOT NULL,               -- 背包大小
    create_time BIGINT NOT NULL,     -- 创建时间
    update_time BIGINT NOT NULL,     -- 更新时间
    UNIQUE KEY idx_user_bag (user_id, bag_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 背包格子表
CREATE TABLE IF NOT EXISTS bag_slots (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,         -- 用户ID
    bag_type TINYINT NOT NULL,       -- 背包类型
    slot_index INT NOT NULL,         -- 格子索引
    state TINYINT NOT NULL,          -- 格子状态
    create_time BIGINT NOT NULL,     -- 创建时间
    update_time BIGINT NOT NULL,     -- 更新时间
    UNIQUE KEY (user_id, bag_type, slot_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 装备属性表
CREATE TABLE IF NOT EXISTS equip_properties (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    equip_id BIGINT NOT NULL,        -- 装备实例ID
    base_props TEXT,                 -- 基础属性(JSON)
    enhance_props TEXT,              -- 强化属性(JSON)
    refine_props TEXT,               -- 精炼属性(JSON)
    gem_props TEXT,                  -- 宝石属性(JSON)
    reforge_props TEXT,              -- 洗练属性(JSON)
    update_time BIGINT NOT NULL      -- 更新时间
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 装备强化记录表
CREATE TABLE IF NOT EXISTS equip_enhance_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,         -- 用户ID
    equip_id BIGINT NOT NULL,        -- 装备ID
    before_level INT NOT NULL,       -- 强化前等级
    after_level INT NOT NULL,        -- 强化后等级
    result TINYINT NOT NULL,         -- 强化结果
    materials TEXT NOT NULL,         -- 消耗材料(JSON)
    time BIGINT NOT NULL,            -- 强化时间
    INDEX idx_equip (equip_id),
    INDEX idx_user_time (user_id, time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; 