local snowflake = require "utils.snowflake"

function M.new(params)
    local now = os.time()
    return {
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.MAIL),  -- 指定类型为邮件
        -- ... 其他字段
    }
end 