local skynet = require "skynet"

local logger = {}

-- 日志等级
logger.LEVEL = {
    DEBUG = 1,
    INFO = 2,
    ERROR = 3
}

-- 日志等级名称
local LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "ERROR"
}

-- 从环境变量获取日志等级，默认 INFO
local current_level = tonumber(os.getenv("LOG_LEVEL")) or logger.LEVEL.INFO

-- 设置日志等级
function logger.set_level(level)
    current_level = level
end

-- 获取当前日志等级
function logger.get_level()
    return current_level
end

-- 基础日志函数
local function log_at_level(level, fmt, ...)
    if level >= current_level then
        local msg = string.format(fmt, ...)
        local time = os.date("%Y-%m-%d %H:%M:%S")
        skynet.error(string.format("[:%08x] [%s] [%s] %s", 
            skynet.self(), time, LEVEL_NAMES[level], msg))
    end
end

-- 各个等级的日志函数
function logger.debug(fmt, ...)
    log_at_level(logger.LEVEL.DEBUG, fmt, ...)
end

function logger.info(fmt, ...)
    log_at_level(logger.LEVEL.INFO, fmt, ...)
end

function logger.error(fmt, ...)
    log_at_level(logger.LEVEL.ERROR, fmt, ...)
end

return logger 