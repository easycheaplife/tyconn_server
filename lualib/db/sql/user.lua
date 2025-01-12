return {
    -- 创建用户表
    create_table = [[
        CREATE TABLE IF NOT EXISTS users (
            user_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
            username VARCHAR(64) NOT NULL COMMENT '用户名',
            password VARCHAR(64) NOT NULL COMMENT '密码',
            nickname VARCHAR(64) NOT NULL COMMENT '昵称',
            level INT DEFAULT 1 COMMENT '等级',
            exp BIGINT DEFAULT 0 COMMENT '经验值',
            vip_level INT DEFAULT 0 COMMENT 'VIP等级',
            gold BIGINT DEFAULT 1000 COMMENT '金币',
            diamond BIGINT DEFAULT 100 COMMENT '钻石',
            avatar VARCHAR(256) DEFAULT 'default.png' COMMENT '头像',
            register_time BIGINT NOT NULL COMMENT '注册时间',
            last_login BIGINT NOT NULL COMMENT '最后登录时间',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
            UNIQUE KEY idx_username (username),
            INDEX idx_register_time (register_time),
            INDEX idx_last_login (last_login)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';
    ]],

    -- 用户查询
    get_by_username = "SELECT * FROM users WHERE username = '%s' LIMIT 1",
    get_by_id = "SELECT * FROM users WHERE user_id = %d LIMIT 1",
    
    -- 用户创建
    create_user = [[
        INSERT INTO users (
            username, password, nickname, avatar, 
            register_time, last_login
        ) VALUES (
            '%s', '%s', '%s', '%s', %d, %d
        )
    ]],
    
    -- 用户更新
    update_user = [[
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
    ]],

    -- 统计查询
    count_total = "SELECT COUNT(*) as count FROM users",
    get_recent_users = [[
        SELECT * FROM users 
        ORDER BY register_time DESC 
        LIMIT 10
    ]]
} 