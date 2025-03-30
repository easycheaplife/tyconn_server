-- 版本表
CREATE TABLE IF NOT EXISTS db_version (
    version INT PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    INDEX idx_user_id_card_id (user_id, card_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户物品表
CREATE TABLE IF NOT EXISTS user_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,  -- 物品实例ID
    user_id BIGINT NOT NULL,         -- 所属用户ID
    item_id INT NOT NULL,            -- 物品模板ID
    count INT NOT NULL,              -- 数量
    bag_type TINYINT,               -- 所在背包类型
    slot_index INT,                 -- 所在格子索引
    bind_type TINYINT DEFAULT 0,     -- 绑定类型
    expire_time BIGINT DEFAULT 0,    -- 过期时间
    create_time BIGINT NOT NULL,     -- 创建时间
    update_time BIGINT NOT NULL,     -- 更新时间
    INDEX idx_user (user_id),
    INDEX idx_item (item_id),
    INDEX idx_expire (expire_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 物品变化日志表
CREATE TABLE IF NOT EXISTS item_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,         -- 用户ID
    item_id INT NOT NULL,            -- 物品ID
    count INT NOT NULL,              -- 变化数量
    type TINYINT NOT NULL,           -- 变化类型(1:增加 2:减少 3:使用)
    source VARCHAR(32) NOT NULL,     -- 变化来源
    before_count INT NOT NULL,       -- 变化前数量
    after_count INT NOT NULL,        -- 变化后数量
    create_time BIGINT NOT NULL,     -- 记录时间
    INDEX idx_user_time (user_id, create_time),
    INDEX idx_item_time (item_id, create_time)
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
    INDEX idx_from_user_time (from_user, time),
    INDEX idx_to_user_time (to_user, time)
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

-- 用户装备槽位表
CREATE TABLE IF NOT EXISTS user_equipment_slots (
    user_id BIGINT NOT NULL,               -- 用户ID
    slot_id INT NOT NULL,                  -- 装备槽位ID (1:武器, 2:护甲, 3:头盔, 4:项链, 5:戒指, 6:靴子...)
    item_id VARCHAR(36),                   -- 装备的物品UUID (NULL表示未装备)
    expire_time BIGINT NOT NULL DEFAULT 0, -- 装备过期时间 (冗余字段，方便检查过期)
    equip_time BIGINT NOT NULL,           -- 装备时间
    update_time BIGINT NOT NULL,          -- 更新时间
    
    PRIMARY KEY (user_id, slot_id),        -- 复合主键，确保一个槽位只有一件装备
    INDEX idx_item_id (item_id),           -- 物品ID索引，用于查找该物品被装备在哪个槽位
    INDEX idx_expire_time (expire_time)    -- 过期时间索引，用于批量检查过期装备
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户装备概率等级表
CREATE TABLE IF NOT EXISTS user_equipment_levels (
    user_id BIGINT PRIMARY KEY,            -- 用户ID
    level INT DEFAULT 1,                   -- 当前装备概率等级
    is_upgrading TINYINT DEFAULT 0,        -- 是否正在升级中 (0:否, 1:是)
    upgrade_start_time BIGINT DEFAULT 0,   -- 升级开始时间
    upgrade_end_time BIGINT DEFAULT 0,     -- 升级预计完成时间
    update_time BIGINT NOT NULL,           -- 更新时间
    
    INDEX idx_upgrading (is_upgrading, upgrade_end_time)  -- 用于批量检查升级完成的记录
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

-- 邮件表
CREATE TABLE IF NOT EXISTS mails (
    id BIGINT PRIMARY KEY,           -- 邮件ID
    user_id BIGINT NOT NULL,         -- 用户ID
    title VARCHAR(128) NOT NULL,     -- 标题
    content TEXT NOT NULL,           -- 内容
    items TEXT,                      -- 附件物品(JSON)
    mail_type INT NOT NULL,          -- 邮件类型
    status INT NOT NULL,             -- 邮件状态
    create_time BIGINT NOT NULL,     -- 创建时间
    update_time BIGINT NOT NULL,     -- 更新时间
    expire_time BIGINT NOT NULL,     -- 过期时间
    template_id BIGINT,              -- 模板ID
    sender_id BIGINT,                -- 发送者ID
    sender_name VARCHAR(32),         -- 发送者名称
    INDEX idx_user_id (user_id),     -- 用户ID索引
    INDEX idx_expire_time (expire_time) -- 过期时间索引
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 邮件模板表
CREATE TABLE IF NOT EXISTS mail_templates (
    id BIGINT PRIMARY KEY,                -- 模板ID
    title VARCHAR(128) NOT NULL,          -- 邮件标题
    content TEXT NOT NULL,                -- 邮件内容
    items TEXT,                           -- 附件物品列表(JSON格式)
    mail_type TINYINT NOT NULL,          -- 邮件类型
    create_time BIGINT NOT NULL,         -- 创建时间
    expire_time BIGINT NOT NULL,         -- 过期时间
    condition_data TEXT,                  -- 发送条件(JSON格式)
    sent_users TEXT,                     -- 已发送用户列表(JSON格式)
    
    INDEX idx_create_time (create_time),  -- 用于查询时间段内的模板
    INDEX idx_expire (expire_time)        -- 用于清理过期模板
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户伙伴表
CREATE TABLE IF NOT EXISTS user_partners (
    id BIGINT PRIMARY KEY,               -- 伙伴唯一ID
    user_id BIGINT NOT NULL,             -- 所属用户ID
    unit_id INT NOT NULL,                -- 单位/伙伴配置ID
    level INT NOT NULL DEFAULT 1,        -- 伙伴等级
    exp INT NOT NULL DEFAULT 0,          -- 伙伴经验
    star INT NOT NULL DEFAULT 0,         -- 伙伴星级
    power INT NOT NULL DEFAULT 0,        -- 伙伴战力（通过属性计算）
    create_time BIGINT NOT NULL,         -- 创建时间
    update_time BIGINT NOT NULL,    -- 最后更新时间
    
    INDEX idx_user_id (user_id),         -- 用户ID索引，用于查询用户所有伙伴
    INDEX idx_unit_id (unit_id)          -- 单位ID索引，用于查询特定类型伙伴
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 伙伴升级日志表
CREATE TABLE IF NOT EXISTS partner_level_logs (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    partner_id BIGINT NOT NULL,          -- 伙伴ID
    user_id BIGINT NOT NULL,             -- 用户ID
    old_level INT NOT NULL,              -- 旧等级
    new_level INT NOT NULL,              -- 新等级
    old_exp INT NOT NULL,                -- 旧经验
    new_exp INT NOT NULL,                -- 新经验
    consume_items TEXT,                  -- 消耗道具JSON
    operation_time BIGINT NOT NULL,      -- 操作时间
    
    INDEX idx_partner_id (partner_id),   -- 伙伴ID索引
    INDEX idx_user_id (user_id)          -- 用户ID索引
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 伙伴升星日志表
CREATE TABLE IF NOT EXISTS partner_star_logs (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    partner_id BIGINT NOT NULL,          -- 伙伴ID
    user_id BIGINT NOT NULL,             -- 用户ID
    old_star INT NOT NULL,               -- 旧星级
    new_star INT NOT NULL,               -- 新星级
    consume_items TEXT,                  -- 消耗道具JSON
    operation_time BIGINT NOT NULL,      -- 操作时间
    
    INDEX idx_partner_id (partner_id),   -- 伙伴ID索引
    INDEX idx_user_id (user_id)          -- 用户ID索引
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 伙伴解锁日志表
CREATE TABLE IF NOT EXISTS partner_unlock_logs (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    partner_id BIGINT NOT NULL,          -- 伙伴ID
    user_id BIGINT NOT NULL,             -- 用户ID
    unit_id INT NOT NULL,                -- 单位ID
    fragment_count INT NOT NULL,         -- 消耗的碎片数量
    operation_time BIGINT NOT NULL,      -- 操作时间
    
    INDEX idx_partner_id (partner_id),   -- 伙伴ID索引
    INDEX idx_user_id (user_id)          -- 用户ID索引
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户大富翁状态表
CREATE TABLE IF NOT EXISTS user_monopoly_state (
    user_id BIGINT PRIMARY KEY,                -- 用户ID
    chapter_id INT NOT NULL DEFAULT 1,         -- 当前章节ID
    current_position INT NOT NULL DEFAULT 0,   -- 当前位置(对应格子ID)
    direction INT NOT NULL DEFAULT 1,          -- 移动方向(1:正向，-1:反向)
    create_time BIGINT NOT NULL,               -- 创建时间
    update_time BIGINT NOT NULL,               -- 更新时间
    
    INDEX idx_chapter (chapter_id)             -- 章节索引，用于查询特定章节的玩家
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 大富翁事件处理表
CREATE TABLE IF NOT EXISTS monopoly_events (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,                   -- 用户ID
    chapter_id INT NOT NULL,                   -- 章节ID
    event_id INT NOT NULL,                     -- 事件ID
    cell_id INT NOT NULL,                      -- 格子ID
    status TINYINT NOT NULL DEFAULT 0,         -- 处理状态(0:未处理,1:处理中,2:已处理)
    trigger_time BIGINT NOT NULL,              -- 触发时间
    complete_time BIGINT DEFAULT 0,            -- 完成时间
    
    INDEX idx_user_status (user_id, status),   -- 用户状态索引，查询用户未处理事件
    INDEX idx_event (event_id),                -- 事件索引
    INDEX idx_trigger (trigger_time)           -- 触发时间索引，用于清理过期事件
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户章节进度表
CREATE TABLE IF NOT EXISTS user_chapter_progress (
    user_id BIGINT NOT NULL,                   -- 用户ID
    chapter_id INT NOT NULL,                   -- 章节ID
    is_passed TINYINT NOT NULL DEFAULT 0,      -- 是否通关(0:未通关,1:已通关)
    reward_claimed TINYINT NOT NULL DEFAULT 0, -- 奖励是否已领取(0:未领取,1:已领取)
    pass_time BIGINT DEFAULT 0,                -- 通关时间
    reward_time BIGINT DEFAULT 0,              -- 领取奖励时间
    steps_count INT DEFAULT 0,                 -- 移动步数
    create_time BIGINT NOT NULL,               -- 创建时间
    update_time BIGINT NOT NULL,               -- 更新时间
    
    PRIMARY KEY (user_id, chapter_id),         -- 复合主键
    INDEX idx_passed (is_passed, reward_claimed) -- 通关状态索引，用于查询已通关未领奖的记录
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 大富翁操作日志表
CREATE TABLE IF NOT EXISTS monopoly_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,                   -- 用户ID
    chapter_id INT NOT NULL,                   -- 章节ID
    operation_type TINYINT NOT NULL,           -- 操作类型(1:掷骰子,2:处理事件,3:领取奖励)
    dice_value INT DEFAULT 0,                  -- 骰子点数(如果是掷骰子操作)
    from_position INT DEFAULT 0,               -- 起始位置(如果是移动操作)
    to_position INT DEFAULT 0,                 -- 目标位置(如果是移动操作)
    event_id INT DEFAULT 0,                    -- 事件ID(如果是事件操作)
    reward_items TEXT,                         -- 奖励物品JSON(如果是领奖操作)
    operation_time BIGINT NOT NULL,            -- 操作时间
    
    INDEX idx_user_time (user_id, operation_time), -- 用户操作时间索引
    INDEX idx_chapter (chapter_id)                -- 章节索引，用于统计分析
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; 
