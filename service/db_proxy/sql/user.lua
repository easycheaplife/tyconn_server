local skynet = require "skynet"
local logger = require "logger"
local mysql = require "db.mysql"

local M = {}

-- 用户相关SQL
M.CHECK_USER_EXISTS = [[
    SELECT user_id FROM users 
    WHERE username = '%s' 
    LIMIT 1
]]

M.CREATE_USER = [[
    INSERT INTO users (
        account, username, name, gender, 
        job, level, exp, create_time
    ) VALUES (
        '%s', '%s', '%s', %d, 
        %d, %d, %d, %d
    )
]]

M.GET_USER_BY_ACCOUNT = [[
    SELECT * FROM users 
    WHERE account = '%s' 
    LIMIT 1
]]

M.UPDATE_USER = [[
    UPDATE users SET 
        name = '%s',
        level = %d,
        exp = %d,
        job = %d,
        gender = %d,
        last_login_time = %d
    WHERE account = '%s'
]]

-- Token相关SQL
M.SYNC_TOKEN = [[
    INSERT INTO user_tokens (
        account, token, device_id, platform, 
        expire_time, create_time
    ) VALUES (
        '%s', '%s', '%s', '%s', 
        %d, %d
    )
]]

M.DELETE_OLD_TOKENS = [[
    DELETE FROM user_tokens 
    WHERE account = '%s'
]]

M.GET_TOKEN = [[
    SELECT * FROM user_tokens 
    WHERE account = '%s' AND token = '%s'
    LIMIT 1
]]

M.CLEAN_EXPIRED_TOKENS = [[
    DELETE FROM user_tokens 
    WHERE expire_time < %d
]]

return M 