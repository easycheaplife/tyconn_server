local skynet = require "skynet"
local logger = require "logger"
local snowflake = require "utils.snowflake"

local M = {}

function M.init()
    logger.info("Game server initializing...")

    -- 1. 设置 snowflake worker_id
    local node_id = tonumber(skynet.getenv("node_id")) or 1
    snowflake.set_worker_id(node_id)

    -- 2. 其他初始化代码...
    local item_service = require "services.item_service"
    item_service.init_default_items()
    item_service.init_item_config()
    logger.info("Game server initialized")
    return true
end

return M 