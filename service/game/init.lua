local skynet = require "skynet"
local logger = require "logger"
local snowflake = require "utils.snowflake"
local config_service = require "services.config_service"

local M = {}

function M.init()
    logger.info("Game server initializing...")

    -- 1. 设置 snowflake worker_id
    local node_id = tonumber(skynet.getenv("node_id")) or 1
    snowflake.set_worker_id(node_id)

    -- 2. 初始化配置
    local ok = config_service.init()
    if not ok then
        logger.error("Failed to init config service")
        return false
    end

    logger.info("Game server initialized")
    return true
end

return M 