local M = {}

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

M.RENEW_TOKEN = [[
    UPDATE user_tokens 
    SET expire_time = %d
    WHERE account = '%s' AND token = '%s'
]]

M.GET_TOKEN_BY_ACCOUNT = [[
    SELECT * FROM user_tokens 
    WHERE account = '%s' 
    ORDER BY create_time DESC 
    LIMIT 1
]]

return M 