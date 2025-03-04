local skynet = require "skynet"
local logger = require "logger"
local snowflake = require "utils.snowflake"
local config_service = require "services.config_service"
local timer_jobs = require "game.timer_jobs"

local M = {}

local services = {}  -- 保存服务地址

function M.init()
    logger.info("Game server initializing...")

    -- 1. 设置 snowflake worker_id
    local node_id = tonumber(skynet.getenv("node_id")) or 1
    snowflake.set_worker_id(node_id)

    -- 2. 启动事件服务
    services.event = skynet.newservice("event_mgr")
    logger.info("Event service started")

    -- 3. 初始化配置
    local ok = config_service.init()
    if not ok then
        logger.error("Failed to init config service")
        return false
    end

    -- 注册定时任务
    timer_jobs.register_all_jobs()

    -- 添加定时器检查装备过期
    skynet.timeout(100, function()
        local equip_service = require "services.equip_service"
        -- 检查所有在线用户的装备过期
        -- 实际实现可能需要遍历在线用户列表
    end)

    logger.info("Game server initialized")
    return true
end

-- 获取服务地址
function M.get_service(name)
    return services[name]
end

return M 