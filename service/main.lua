local skynet = require "skynet"
local logger = require "logger"

skynet.start(function()
	logger.info("Server starting...")
	
	-- 启动游戏服务
	local game = skynet.newservice("game")
	
	-- 启动 watchdog
	local watchdog = skynet.newservice("ws_watchdog")
	local port = 8891
	
	local ok = skynet.call(watchdog, "lua", "start", {
		port = port,
		game = game
	})
	
	if ok then
		logger.info("WebSocket gate listening on 0.0.0.0:%d", port)
		logger.info("Server started")
	else
		logger.error("Failed to start server")
		skynet.exit()
	end
end)

