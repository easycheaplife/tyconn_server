-- 添加邮箱字段
ALTER TABLE users ADD COLUMN email VARCHAR(255) AFTER username;

-- 添加邮箱索引
ALTER TABLE users ADD INDEX idx_email (email);

-- 更新版本
UPDATE db_version SET version = 2; 