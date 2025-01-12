-- 创建数据库
CREATE DATABASE IF NOT EXISTS tyconn DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tyconn;

-- 创建用户表
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