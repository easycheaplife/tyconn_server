local skynet = require "skynet"
local logger = require "logger"
local db_util = require "db_proxy.utils.db_util"

local M = {}

-- 获取当前数据库版本
local function get_current_version()
    local result = db_util.query("SELECT version FROM db_version ORDER BY version DESC LIMIT 1")
    if not result or #result == 0 then
        return 0
    end
    return result[1].version
end

-- 执行SQL文件
local function execute_sql_file(filename)
    local file = io.open(filename, "r")
    if not file then
        logger.error("Failed to open SQL file: %s", filename)
        return false
    end

    local sql = file:read("*a")
    file:close()

    -- 分割SQL语句
    for statement in sql:gmatch("[^;]+") do
        statement = statement:gsub("^%s+", ""):gsub("%s+$", "")
        if statement ~= "" then
            local ok = db_util.query(statement)
            if not ok then
                logger.error("Failed to execute SQL: %s", statement)
                return false
            end
        end
    end
    return true
end

-- 初始化数据库表
function M.init()
    -- 获取当前版本
    local current_version = get_current_version()
    logger.info("Current database version: %d", current_version)

    -- 执行SQL文件
    local sql_dir = "./sql"
    local files = {}
    for file in io.popen('ls -v ' .. sql_dir .. '/*.sql'):lines() do
        table.insert(files, file)
    end

    -- 按文件名排序执行
    for _, file in ipairs(files) do
        local version = tonumber(file:match("(%d+)_"))
        if version and version > current_version then
            logger.info("Executing SQL file: %s", file)
            if not execute_sql_file(file) then
                return false
            end
        end
    end

    return true
end

return M 