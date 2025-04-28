local cjson = require "cjson"
local M = {}

-- 自定义数字格式化
local function number_formatter(n)
    if type(n) ~= "number" then
        return n
    end
    -- 只对大整数使用字符串格式，普通整数保持数字类型
    if n >= 1e10 then
        return string.format("%.0f", n)
    end
    return n
end

-- 递归处理表中的数字，用于JSON编码
function M.process_for_json(t)
    if type(t) ~= "table" then
        return number_formatter(t)
    end
    
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = M.process_for_json(v)
        else
            result[k] = number_formatter(v)
        end
    end
    return result
end

-- JSON编码（避免科学计数法）
function M.encode_json(data)
    -- 先处理所有数字
    local processed = M.process_for_json(data)
    -- 然后进行JSON编码
    return cjson.encode(processed)
end

-- JSON解码
function M.decode_json(str)
    if not str then return nil end
    local ok, result = pcall(cjson.decode, str)
    if not ok then return nil end
    return result
end

-- 将表转换为字符串
function M.table_to_string(t, indent)
    if not t then return "nil" end
    if type(t) ~= "table" then return tostring(t) end
    
    indent = indent or ""
    local formatted = M.process_number_table(t)  -- 先处理数字格式
    local lines = {}
    local subIndent = indent .. "  "
    
    for k, v in pairs(formatted) do
        if type(v) == "table" then
            table.insert(lines, string.format("%s%s = {", indent, tostring(k)))
            table.insert(lines, M.table_to_string(v, subIndent))
            table.insert(lines, string.format("%s}", indent))
        else
            table.insert(lines, string.format("%s%s = %s", indent, tostring(k), tostring(v)))
        end
    end
    
    return table.concat(lines, "\n")
end

-- 打印表内容（用于调试）
function M.print_table(t, name)
    name = name or "table"
    print(string.format("%s = {", name))
    print(M.table_to_string(t, "  "))
    print("}")
end

-- 将 "YYYY-MM-DD HH:MM:SS" 格式或数字转换为 UNIX 时间戳
function M.datetime_to_timestamp(datetime)
    if not datetime then return 0 end
    
    -- 如果已经是数字，直接返回
    if type(datetime) == "number" then
        return datetime
    end
    
    -- 如果是字符串，解析日期时间
    if type(datetime) == "string" then
        local year, month, day, hour, min, sec = 
            datetime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        
        if not year then return 0 end
        
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end
    
    return 0
end

-- 将 UNIX 时间戳转换为 "YYYY-MM-DD HH:MM:SS" 格式
function M.timestamp_to_datetime(timestamp)
    if not timestamp or timestamp == 0 then
        return os.date("%Y-%m-%d %H:%M:%S", os.time())
    end
    return os.date("%Y-%m-%d %H:%M:%S", tonumber(timestamp))
end

-- 深度复制表
function M.deep_copy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deep_copy(orig_key)] = M.deep_copy(orig_value)
        end
        setmetatable(copy, M.deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 格式化数字，避免科学计数法
function M.format_number(n)
    if type(n) ~= "number" then
        return n
    end
    -- 如果是整数或大数，使用字符串格式
    if n >= 1e10 or math.floor(n) == n then
        return string.format("%.0f", n)
    end
    return n
end

-- 递归处理表中的数字
function M.process_number_table(t)
    if type(t) ~= "table" then
        return M.format_number(t)
    end
    
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = M.process_number_table(v)
        else
            result[k] = M.format_number(v)
        end
    end
    return result
end

return M