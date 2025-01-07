local skynet = require "skynet"
local logger = require "logger"  -- 引入日志模块
local log = logger.log          -- 简化调用

-- 保存重要的服务句柄
local SERVICES = {}

local function start_watchdog(game_service)
	local watchdog = skynet.newservice("ws_watchdog")
	local port = 8891  -- 从配置文件读取或使用默认值
	
	local ok = skynet.call(watchdog, "lua", "start", {
		port = port,
		game = game_service
	})
	
	if ok then
		log("WebSocket gate listening on 0.0.0.0:%d", port)
	else
		log("Failed to start WebSocket gate")
	end
	
	return watchdog
end

-- 添加获取服务句柄的接口
local CMD = {}

function CMD.get_service(name)
	return SERVICES[name]
end

skynet.start(function()
	-- 启动必要的服务
	log("Server starting...")
	
	-- 启动游戏服务
	local game = skynet.newservice("game")
	log("Game service %d started successfully", game)
	
	-- 启动 watchdog（它会创建并管理 gate）
	local watchdog = start_watchdog(game)
	
	-- 存储服务句柄到本地表
	SERVICES.game = game
	SERVICES.watchdog = watchdog
	
	-- 添加消息分发
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		end
	end)
	
	log("Server started")
	
	-- 如果是后台运行则注释掉这行
	-- skynet.exit()
end)

