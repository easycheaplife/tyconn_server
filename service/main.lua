-- main.lua
-- 服务器入口
-- 负责启动和初始化所有必要的服务
-- 包括游戏服务和 WebSocket 网关

local skynet = require "skynet"
local logger = require "logger"

-- 服务入口
skynet.start(function()
	logger.info("Server starting...")
	
	-- 启动游戏服务
	-- 游戏服务负责处理具体的游戏逻辑
	local game = skynet.newservice("game")
	
	-- 启动 WebSocket 看门狗服务
	-- 看门狗服务负责创建和管理 WebSocket 网关
	local watchdog = skynet.newservice("ws_watchdog")
	local port = 8891  -- WebSocket 监听端口
	
	-- 启动 WebSocket 网关
	local ok = skynet.call(watchdog, "lua", "start", {
		port = port,    -- 监听端口
		game = game     -- 游戏服务句柄
	})
	
	-- 检查启动结果
	if ok then
		logger.info("WebSocket gate listening on 0.0.0.0:%d", port)
		logger.info("Server started")
	else
		logger.error("Failed to start server")
		skynet.exit()
	end
end)

