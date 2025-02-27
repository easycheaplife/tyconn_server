local snowflake = require "utils.snowflake"

-- 用户数据模型定义
local M = {}

-- 创建新用户模型
function M.new(params)
    local now = os.time()
    return {
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.USER),  -- 指定类型为用户
        -- 基础信息
        user_id = params.user_id,
        account = params.account,
        username = params.username,
        password = params.password,
        nickname = params.nickname or params.username,
        avatar = params.avatar or "default.png",
        
        -- 等级相关
        level = params.level or 1,
        exp = params.exp or 0,
        vip_level = params.vip_level or 0,
        
        -- 货币相关
        gold = params.gold or 1000,
        diamond = params.diamond or 100,
        
        -- 单位相关
        unit_id = params.unit_id,
        
        -- 属性相关
        hp = params.hp or 0,
        attack = params.attack or 0,
        defense = params.defense or 0,
        
        -- 时间相关
        register_time = params.register_time or now,
        last_login = params.last_login or now,
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 验证用户数据
function M.validate(user_data)
    if not user_data then
        return false, "user data is empty"
    end
    
    if not user_data.account then
        return false, "account is empty"
    end
    
    if not user_data.username then
        return false, "username is empty"
    end
    
    return true
end

return M 