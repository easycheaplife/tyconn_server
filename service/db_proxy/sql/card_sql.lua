local M = {}

M.INSERT_CARD = [[
    INSERT INTO user_cards (
        id, user_id, card_id, level, exp, star, quality,
        power, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d, %d,
        %d, %d, %d
    )
]]

M.GET_USER_CARDS = [[
    SELECT 
        id,
        card_id,
        level,
        exp,
        quality,
        star,
        power,
        create_time,
        update_time
    FROM user_cards 
    WHERE user_id = %d
    ORDER BY power DESC, level DESC, id ASC
]]

M.UPDATE_CARD = [[
    UPDATE user_cards SET
        level = %d,
        exp = %d,
        star = %d,
        quality = %d,
        power = %d,
        update_time = %d
    WHERE id = %d AND user_id = %d
]]

M.CREATE_CARD = [[
    INSERT INTO user_cards (
        id, user_id, card_id, card_type, level, exp, 
        star, quality, power, create_time, update_time
    ) VALUES (
        %d, %d, %d, %d, %d, %d, 
        %d, %d, %d, %d, %d
    )
]]

return M 