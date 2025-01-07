-- ws_watchdog.lua
-- WebSocket 看门狗服务
-- 负责创建和管理 WebSocket 网关服务
-- 作为 WebSocket 网关的启动入口

local skynet = require "skynet"

-- 服务入口
skynet.start(function()
    -- 处理服务消息
    skynet.dispatch("lua", function(session, source, cmd, conf)
        -- 只处理 start 命令
        if cmd == "start" then
            -- 创建 WebSocket 网关服务
            local gate = skynet.newservice("ws_gate")
            -- 启动网关服务并返回结果
            skynet.ret(skynet.pack(skynet.call(gate, "lua", "start", conf)))
        end
    end)
end) 