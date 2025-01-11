local M = {}

-- 打印表内容的辅助函数
function M.table_to_string(t)
    if not t then return "nil" end
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            table.insert(result, k .. "=" .. M.table_to_string(v))
        else
            table.insert(result, k .. "=" .. tostring(v))
        end
    end
    return "{" .. table.concat(result, ", ") .. "}"
end

return M