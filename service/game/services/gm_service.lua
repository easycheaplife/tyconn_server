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
        if #params < 2 then
            return false, "参数不足"
        end
        
        local item_id = tonumber(params[1])
        local count = tonumber(params[2])
        if not item_id or not count then
            return false, "无效的参数"
        end

        -- 使用batch_add_items保持与item_service一致
        local ok, err = item_service.batch_add_items(user_id, {
            { item_id = item_id, count = count }
        })
        if not ok then
            return false, err
        end
        
        logger.info("GM added items - user_id: %d, item_id: %d, count: %d",
            user_id, item_id, count)
        return true, string.format("添加物品成功: %d x %d", item_id, count)
    end,

    -- 删除物品
    del_item = function(user_id, params)
        if #params < 2 then
            return false, "参数不足"
        end

        local item_id = tonumber(params[1])
        local count = tonumber(params[2])
        if not item_id or not count then
            return false, "无效的参数"
        end

        -- 使用use_item保持与item_service一致
        local ok, err = item_service.use_item(user_id, item_id, count)
        if not ok then
            return false, err
        end

        logger.info("GM deleted items - user_id: %d, item_id: %d, count: %d",
            user_id, item_id, count)
        return true, string.format("删除物品成功: %d x %d", item_id, count)
    end,

    -- 清空背包
    clear_bag = function(user_id, params)
        -- 先获取所有物品
        local items = item_service.get_user_items(user_id)
        if not items then
            return false, "获取背包失败"
        end

        -- 使用batch_delete_items保持与item_service一致
        local ok = item_service.batch_delete_items(user_id, items)
        if not ok then
            return false, "清空背包失败"
        end

        logger.info("GM cleared bag - user_id: %d", user_id)
        return true, "清空背包成功"
    end,

    -- 设置等级
    set_level = function(user_id, params)
        if #params < 1 then
            return false, "参数不足"
        end

        local level = tonumber(params[1])
        if not level then
            return false, "无效的等级参数"
        end

        -- 检查GM权限
        if not user_service.check_gm_permission(user_id) then
            return false, "没有GM权限"
        end

        local ok, err = user_service.set_level(user_id, level)
        if not ok then
            return false, err
        end

        logger.info("GM set level - user_id: %d, level: %d", user_id, level)
        return true, string.format("设置等级成功: %d", level)
    end
}

-- 执行GM指令
function M.execute_command(user_id, command, params)
    -- 检查参数
    if not user_id or not command then
        return false, "参数错误"
    end

    -- 获取处理函数
    local handler = GM_HANDLERS[command]
    if not handler then
        logger.warn("Invalid GM command: %s", command)
        return false, "无效的GM指令"
    end

    -- 执行指令
    local ok, msg = xpcall(function()
        return handler(user_id, params)
    end, debug.traceback)

    if not ok then
        logger.error("GM command failed: %s", msg)
        return false, "GM指令执行失败"
    end

    return msg
end

return M 