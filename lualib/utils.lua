local M = {}

-- 将表转换为字符串
function M.table_to_string(t, indent)
    if not t then return "nil" end
    if type(t) ~= "table" then return tostring(t) end
    
    indent = indent or ""
    local lines = {}
    local order = {}
    
    for k in pairs(t) do
        table.insert(order, k)
    end
    table.sort(order)
    
    for _, k in ipairs(order) do
        local v = t[k]
        if type(v) == "table" then
            table.insert(lines, string.format("%s%s = {", indent, k))
            table.insert(lines, M.table_to_string(v, indent.."  "))
            table.insert(lines, indent.."}")
        else
            if type(v) == "string" then
                v = string.format('"%s"', v)
            end
            table.insert(lines, string.format("%s%s = %s", indent, k, tostring(v)))
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

return M