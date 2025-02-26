local skynet = require "skynet"
local logger = require "logger"
local mysql = require "mysql"

local M = {}

-- 用户相关SQL
M.GET_USER_BY_ID = [[
    SELECT 
        user_id,
        account,
        username,
        level,
        exp,
        vip_level,
        create_time,
        last_login_time as login_time
    FROM users 
    WHERE user_id = %d 
    LIMIT 1
]]

M.GET_USER_BY_ACCOUNT = [[
    SELECT 
        user_id,
        account,
        username,
        level,
        exp,
        vip_level,
        create_time,
        last_login_time,
        last_login_time as login_time
    FROM users 
    WHERE account = '%s' 
    LIMIT 1
]]

M.GET_USER_BY_USERNAME = [[
    SELECT 
        user_id,
        account,
        username,
        level,
        exp,
        vip_level,
        create_time,
        last_login_time as login_time
    FROM users 
    WHERE username = '%s' 
    LIMIT 1
]]

M.CREATE_USER = [[
    INSERT INTO users (
        account, username, level, exp,
        vip_level, create_time, last_login_time
    ) VALUES (
        '%s', '%s', %d, %d,
        %d, %d, %d
    )
]]

M.UPDATE_USER = [[
    UPDATE users SET 
        level = %d,
        exp = %d,
        vip_level = %d,
        last_login_time = %d
    WHERE account = '%s'
]]

M.GET_TOTAL_USERS = [[
    SELECT COUNT(*) as count 
    FROM users
]]

M.GET_RECENT_USERS = [[
    SELECT * FROM users 
    ORDER BY last_login_time DESC 
    LIMIT 10
]]

M.GET_ONLINE_USERS = [[
    SELECT COUNT(*) as count 
    FROM users 
    WHERE last_login_time > %d 
    AND last_login_time + 300 > %d
]]

M.CHECK_NAME_EXISTS = nil

return M 