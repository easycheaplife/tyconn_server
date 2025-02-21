local skynet = require "skynet"
local logger = require "logger"
local db_util = require "db_proxy.utils.db_util"
local sql = require "db_proxy.sql.init"
local snowflake = require "utils.snowflake"

local M = {}

function M.init()
    logger.info("DB proxy initializing...")

    -- 1. 设置 snowflake worker_id
    local node_id = tonumber(skynet.getenv("node_id")) or 1
    snowflake.set_worker_id(node_id)

    -- 2. 初始化数据库连接
    if not db_util.init() then
        logger.error("Failed to initialize MySQL connection")
        return false
    end
    
    if not sql.init() then
        logger.error("Failed to initialize database tables")
        return false
    end
    
    logger.info("DB proxy initialized")
    return true
end

return M 