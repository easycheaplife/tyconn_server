-- logger.lua
-- 日志模块，提供分级日志功能
-- 支持 DEBUG、INFO、ERROR 三个日志等级
-- 可通过环境变量 LOG_LEVEL 设置日志等级

local skynet = require "skynet"

local LOG_LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

local LOG_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL"
}

local M = {}

-- 获取日志文件路径
local function get_log_file()
    local node_name = skynet.getenv("node_name") or "unknown"
    local date = os.date("%Y-%m-%d")
    local log_file = string.format("logs/%s_%s.log", node_name, date)
    
    -- 确保日志目录存在
    os.execute("mkdir -p logs")
    
    return log_file
end

-- 获取调用者信息
local function get_caller_info()
    local level = 4  -- 跳过 write_log、logger函数(debug/info/error等)、get_caller_info 这三层调用栈
    local info
    
    -- 向上查找第一个非 logger.lua 的调用位置
    repeat
        info = debug.getinfo(level, "Sl")
        level = level + 1
    until not info or not string.match(info.short_src, "logger.lua$")
    
    if info then
        -- 去掉路径前缀，只保留文件名
        local filename = string.match(info.short_src, "([^/]+)$") or info.short_src
        return string.format("%s:%d", filename, info.currentline)
    end
    
    return "unknown:0"
end

-- 格式化日志消息
local function format_log(level, fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then
        return string.format("[Error formatting log message: %s] fmt: %s", msg, fmt)
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local caller = get_caller_info()
    return string.format("[%s] [%s] [%s] %s\n", 
        timestamp,
        LOG_NAMES[level], 
        caller,
        msg)
end

-- 写入日志
local function write_log(level, fmt, ...)
    local min_level = tonumber(skynet.getenv("LOG_LEVEL")) or LOG_LEVEL.DEBUG
    if level < min_level then
        return
    end
    
    local msg = format_log(level, fmt, ...)
    
    -- 输出到控制台
    skynet.error(msg)
    
    -- 输出到文件
    local log_file = get_log_file()
    local file = io.open(log_file, "a+")
    if file then
        file:write(msg)
        file:close()
    end
end

function M.debug(fmt, ...)
    write_log(LOG_LEVEL.DEBUG, fmt, ...)
end

function M.info(fmt, ...)
    write_log(LOG_LEVEL.INFO, fmt, ...)
end

function M.warn(fmt, ...)
    write_log(LOG_LEVEL.WARN, fmt, ...)
end

function M.error(fmt, ...)
    write_log(LOG_LEVEL.ERROR, fmt, ...)
end

function M.fatal(fmt, ...)
    write_log(LOG_LEVEL.FATAL, fmt, ...)
end

return M 