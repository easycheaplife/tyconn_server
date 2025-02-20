local cjson = require "cjson"
local logger = require "logger"

local M = {}

local config_cache = {}

-- 递归处理数值，将浮点数转换为整数（如果可能）
local function process_numbers(data)
    if type(data) ~= "table" then
        -- 如果是数字且没有小数部分，转换为整数
        if type(data) == "number" and math.floor(data) == data then
            return math.floor(data)
        end
        return data
    end
    
    local result = {}
    for k, v in pairs(data) do
        -- 处理key
        if type(k) == "number" and math.floor(k) == k then
            k = math.floor(k)
        end
        -- 递归处理value
        result[k] = process_numbers(v)
    end
    return result
end

-- 从文件加载JSON配置
local function load_json_file(file_path)
    local f = io.open(file_path, "r")
    if not f then
        logger.error("Failed to open config file: %s", file_path)
        return nil
    end
    
    local content = f:read("*all")
    f:close()
    
    local ok, data = pcall(cjson.decode, content)
    if not ok then
        logger.error("Failed to parse JSON file %s: %s", file_path, data)
        return nil
    end
    
    -- 处理数值类型
    return process_numbers(data)
end

-- 获取配置数据
function M.get_config(name)
    if config_cache[name] then
        return config_cache[name]
    end
    
    local file_path = string.format("./config/%s.json", name)
    local data = load_json_file(file_path)
    if data then
        config_cache[name] = data
    end
    return data
end

return M 