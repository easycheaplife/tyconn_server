local M = {}

M.INSERT_PARTNER = [[
    INSERT INTO user_partners (
        id, user_id, unit_id, level, exp, star,
        power, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d,
        %d, %d, %d
    )
]]

M.GET_USER_PARTNERS = [[
    SELECT 
        id,
        user_id,
        unit_id,
        level,
        exp,
        star,
        power,
        create_time,
        update_time
    FROM user_partners 
    WHERE user_id = %d
    ORDER BY power DESC, level DESC, id ASC
]]

M.GET_PARTNER = [[
    SELECT 
        id,
        user_id,
        unit_id,
        level,
        exp,
        star,
        power,
        create_time,
        update_time
    FROM user_partners 
    WHERE id = %d
]]

M.UPDATE_PARTNER = [[
    UPDATE user_partners SET
        level = %d,
        exp = %d,
        star = %d,
        power = %d,
        update_time = %d
    WHERE id = %d AND user_id = %d
]]

M.CREATE_PARTNER = [[
    INSERT INTO user_partners (
        id, user_id, unit_id, level, exp, 
        star, power, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, 
        %d, %d, %d, %d
    )
]]

M.DELETE_PARTNER = [[
    DELETE FROM user_partners 
    WHERE id = %d AND user_id = %d
]]

M.CHECK_PARTNER_EXISTS = [[
    SELECT COUNT(*) AS count 
    FROM user_partners 
    WHERE user_id = %d AND unit_id = %d
]]

-- 伙伴等级变化日志
M.LOG_PARTNER_LEVEL_CHANGE = [[
    INSERT INTO partner_level_logs (
        partner_id, user_id, old_level, new_level, 
        change_time, extra_info
    ) VALUES (
        %d, %d, %d, %d, 
        %d, '%s'
    )
]]

-- 伙伴星级变化日志
M.LOG_PARTNER_STAR_CHANGE = [[
    INSERT INTO partner_star_logs (
        partner_id, user_id, old_star, new_star, 
        change_time, extra_info
    ) VALUES (
        %d, %d, %d, %d, 
        %d, '%s'
    )
]]

-- 伙伴解锁日志
M.LOG_PARTNER_UNLOCK = [[
    INSERT INTO partner_unlock_logs (
        partner_id, user_id, unit_id, fragment_count, 
        change_time, extra_info
    ) VALUES (
        %d, %d, %d, %d, 
        %d, '%s'
    )
]]

return M