local skynet = require "skynet"
local logger = require "logger"
local item_service = require "services.item_service"
local user_service = require "services.user_service"
local utils = require "utils"

local M = {}

-- GM指令处理函数表
local GM_HANDLERS = {
    -- 添加物品
    add_item = function(user_id, params)
        if #params < 1 then
            return false, "参数不足"
        end

        local item_id = tonumber(params[1])
        local count = tonumber(params[2] or 1)
        if not item_id or not count or count <= 0 then
            logger.error("add_item - params: %s", utils.table_to_string(params))
            return false, "参数无效"
        end
        
        local result, err = item_service.add_items_to_slot(user_id, {
            {
                item_id = item_id,
                count = count
            }
        })
        logger.info("add_item - result: %s, err: %s", result, err)
        if not result then
            return false, err
        end

        return true, "添加物品成功"
    end,

    -- 删除物品
    del_item = function(user_id, params)
        if #params < 1 then
            return false, "参数不足"
        end

        local item_id = tonumber(params[1])
        local count = tonumber(params[2] or 1)
        
        if not item_id or count <= 0 then
            return false, "参数无效"
        end
        
        return item_service.batch_remove_items(user_id, {
            {
                item_id = item_id,
                count = count
            }
        })
    end,

    -- 清空背包
    clear_bag = function(user_id, args)
        -- 参数检查
        if not args[1] then
            return false, "缺少背包类型参数"
        end
        
        local bag_type = tonumber(args[1])
        if not bag_type then
            return false, "背包类型必须是数字"
        end
        
        -- 调用背包服务清空背包
        local bag_service = require "services.bag_service"
        local ok, msg = bag_service.clear_bag(user_id, bag_type)
        if not ok then
            return false, msg
        end
        
        return true, "背包已清空"
    end,

    -- 设置等级
    set_level = function(user_id, params)
        if #params < 1 then
            return false, "参数不足"
        end
        
        local level = tonumber(params[1])
        logger.info("GM set level - level: %d", level)
        if not level or level <= 0 then
            return false, "等级参数无效"
        end

        -- 计算所需经验值
        local need_exp = (level - 1) * 1000
        
        -- 获取当前用户信息
        logger.info("GM set level - user_id: %d, level: %d", user_id, level)
        local user = user_service.get_user_by_id(user_id)
        logger.info("GM set level - user: %s", utils.table_to_string(user))
        if not user then
            return false, "用户不存在"
        end

        if user.level >= level then
            return true, "等级已达到"
        end
        -- 设置经验值会自动更新等级
        local ok, err = user_service.add_exp(user_id, need_exp - (user.exp or 0))
        if not ok then
            return false, err
        end
        logger.info("GM set level - ok: %s, err: %s", ok, err)
        return true, string.format("设置等级成功: %d", level)
    end,

    -- 重置用户
    reset_user = function(user_id, params)
        return user_service.reset_user(user_id)
    end,

    -- 封禁用户
    ban_user = function(user_id, params)
        local target_id = tonumber(params[1])
        local duration = tonumber(params[2] or 3600) -- 默认1小时
        
        if not target_id or duration <= 0 then
            return false, "参数无效"
        end
        
        return user_service.ban_user(target_id, duration)
    end
}

-- 执行GM指令
function M.execute_command(user_id, command, params)
    -- 1. 检查权限
    local ok, err = user_service.check_gm_permission(user_id)
    if not ok then
        return false, err
    end

    -- 2. 获取命令处理器
    local handler = GM_HANDLERS[command]
    if not handler then
        logger.warn("Invalid GM command: %s", command)
        return false, "未知的GM命令"
    end

    -- 3. 执行命令
    local ok, result = xpcall(function()
        return handler(user_id, params)
    end, debug.traceback)

    if not ok then
        logger.error("GM command failed: %s", result)
        return false, "GM指令执行失败"
    end

    return result
end

return M 