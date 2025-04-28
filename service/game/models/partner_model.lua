local snowflake = require "utils.snowflake"

-- 伙伴数据模型定义
local M = {}

-- 创建新伙伴模型
function M.new(params)
    local now = os.time()
    return {
        -- 基础信息
        id = params.id or snowflake.next_id(snowflake.ID_TYPE.PARTNER),
        user_id = params.user_id,
        unit_id = params.unit_id,
        
        -- 等级和属性相关
        level = params.level or 1,
        exp = params.exp or 0,
        star = params.star or 1,
        quality = params.quality or 1,
        race = params.race,
        forte = params.forte,
        
        -- 属性和战力
        properties = params.properties or {},
        power = params.power or 0,
        
        -- 时间相关
        create_time = params.create_time or now,
        update_time = params.update_time or now
    }
end

-- 验证伙伴数据
function M.validate(partner_data)
    if not partner_data then
        return false, "partner data is empty"
    end
    
    if not partner_data.user_id then
        return false, "user id is empty"
    end
    
    if not partner_data.unit_id then
        return false, "unit id is empty"
    end
    
    return true
end

return M 