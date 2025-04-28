-- example 目录测试配置文件

root = "./"
thread = 8
harbor = 0
luaservice = root.."service/?.lua;"..root.."example/?.lua;"..root.."skynet/service/?.lua"
lualoader = root.."skynet/lualib/loader.lua"

-- 修改 lua_path，确保它包含所有需要的路径
lua_path = root.."lualib/?.lua;"..root.."service/?.lua;"..root.."skynet/lualib/?.lua;"..root.."skynet/lualib/?/init.lua"
-- 添加下面这行，明确指出module路径格式
lua_path = lua_path..";"..root.."service/game/utils/?.lua"
-- 添加这行，使game.utils.snowflake格式可以找到snowflake.lua
lua_path = lua_path..";"..root.."service/?.lua"

lua_cpath = root.."skynet/luaclib/?.so"
cpath = root.."skynet/cservice/?.so"

-- 指定启动脚本为snowflake_test
start = "snowflake_test"
bootstrap = "snlua bootstrap"

-- 调试设置
logger = nil
logpath = "."
console_port = 8000

-- 自定义配置
env = "test"               -- 测试环境标记
worker_id = 1              -- 设置Worker ID，用于Snowflake ID生成
log_level = "debug"        -- 设置日志级别为debug，便于观察测试详情

-- Daemon模式
--daemon = "./skynet-test.pid"  -- 取消注释以启用daemon模式 