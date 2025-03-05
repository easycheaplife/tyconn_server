local skynet = require "skynet"
local logger = require "logger"
local db_util = require "db_proxy.utils.db_util"

local M = {}

function M.ping(node_name)
    -- 使用简单的 SELECT 1 查询来测试连接
    local ok, err = db_util.query("SELECT 1")
    if not ok then
        logger.error("Database ping failed from %s: %s", node_name or "unknown", err)
        return false
    end
    
    return true
end

return M 