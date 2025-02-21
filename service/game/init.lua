local skynet = require "skynet"
local snowflake = require "utils.snowflake"

local function init()
    -- 1. 设置 snowflake worker_id
    local node_id = tonumber(skynet.getenv("node_id")) or 1
    snowflake.set_worker_id(node_id)

    -- 2. 其他初始化代码...
    local item_service = require "services.item_service"
    item_service.schedule_clean_expired_items()
end

skynet.start(function()
    init()
    -- ... 其他启动代码
end) 