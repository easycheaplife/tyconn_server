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

return M