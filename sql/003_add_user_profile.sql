-- 添加用户资料字段
ALTER TABLE users 
ADD COLUMN avatar VARCHAR(255) AFTER email,
ADD COLUMN vip_level INT DEFAULT 0 AFTER level,
ADD COLUMN vip_exp BIGINT DEFAULT 0 AFTER vip_level;

-- 更新版本
UPDATE db_version SET version = 3; 