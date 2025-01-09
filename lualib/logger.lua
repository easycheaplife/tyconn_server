-- logger.lua
-- 日志模块，提供分级日志功能
-- 支持 DEBUG、INFO、ERROR 三个日志等级
-- 可通过环境变量 LOG_LEVEL 设置日志等级

local skynet = require "skynet"

local logger = {}

-- 日志等级定义
-- DEBUG = 1: 调试信息，用于开发调试，包含详细的消息收发信息
-- INFO = 2:  一般信息，用于记录重要状态变化，如服务启动、连接建立等
-- ERROR = 3: 错误信息，用于记录异常情况
logger.LEVEL = {
    DEBUG = 1,
    INFO = 2,
    ERROR = 3
}

-- 日志等级名称映射表，用于日志输出时显示等级名称
local LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "ERROR"
}

-- 从环境变量获取日志等级，如果未设置则默认使用 DEBUG 级别
-- 可在 config 文件中通过 env = "LOG_LEVEL=1" 设置
local current_level = tonumber(os.getenv("LOG_LEVEL")) or logger.LEVEL.DEBUG

-- 设置日志等级
-- @param level: 日志等级，取值为 logger.LEVEL 中的值
function logger.set_level(level)
    current_level = level
end

-- 获取当前日志等级
-- @return: 当前日志等级
function logger.get_level()
    return current_level
end

-- 基础日志输出函数
-- @param level: 日志等级
-- @param fmt: 格式化字符串
-- @param ...: 格式化参数
local function log_at_level(level, fmt, ...)
    -- 只输出大于等于当前等级的日志
    if level >= current_level then
        local msg = string.format(fmt, ...)
        local time = os.date("%Y-%m-%d %H:%M:%S")
        -- 日志格式：[服务地址] [时间] [日志等级] 消息内容
        skynet.error(string.format("[:%08x] [%s] [%s] %s", 
            skynet.self(), time, LEVEL_NAMES[level], msg))
    end
end

-- DEBUG 级别日志输出
function logger.debug(fmt, ...)
    log_at_level(logger.LEVEL.DEBUG, fmt, ...)
end

-- INFO 级别日志输出
function logger.info(fmt, ...)
    log_at_level(logger.LEVEL.INFO, fmt, ...)
end

-- ERROR 级别日志输出
function logger.error(fmt, ...)
    log_at_level(logger.LEVEL.ERROR, fmt, ...)
end

return logger 