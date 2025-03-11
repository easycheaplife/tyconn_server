local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        print("Failed to open file: " .. path)
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "w")
    if not file then
        print("Failed to open file: " .. path)
        return false
    end
    file:write(content)
    file:close()
    return true
end

-- 解析proto文件中的枚举定义
local function parse_enums(content)
    local enums = {}
    local current_enum = nil
    local last_comment = nil
    
    -- 移除package和import语句
    content = content:gsub("package%s+[%w%.]+;", "")
    content = content:gsub("import%s+[^;]+;", "")
    
    for line in content:gmatch("[^\r\n]+") do
        -- 跳过空行和语法标记行
        if line:match("^%s*$") or line:match("^%s*syntax%s*=") then
            goto continue
        end
        
        -- 保存注释行
        local comment = line:match("^%s*//(.+)")
        if comment then
            last_comment = comment:match("^%s*(.-)%s*$")
            goto continue
        end
        
        -- 匹配枚举开始
        local enum_name = line:match("^%s*enum%s+(%w+)%s*{")
        if enum_name then
            current_enum = {
                name = enum_name,
                values = {},
                comment = last_comment or ""
            }
            last_comment = nil
            enums[#enums + 1] = current_enum
            goto continue
        end
        
        -- 匹配枚举值
        if current_enum then
            -- 修改正则表达式以更准确地匹配枚举值
            local name, value, comment = line:match("^%s*(%u[%u_]*)%s*=%s*(%d+)%s*;?%s*(//?.*)$")
            if not name then
                name, value = line:match("^%s*(%u[%u_]*)%s*=%s*(%d+)%s*;?%s*$")
            end
            if name and value then
                -- 去掉注释中的 // 或 / 前缀
                if comment then
                    comment = comment:match("^/?/?%s*(.-)%s*$") or ""
                else
                    comment = last_comment or ""
                end
                
                current_enum.values[#current_enum.values + 1] = {
                    name = name,
                    value = tonumber(value),
                    comment = comment
                }
                last_comment = nil
            end
        end
        
        -- 匹配枚举结束
        if line:match("^%s*}") then
            current_enum = nil
            last_comment = nil
        end
        
        ::continue::
    end
    
    return enums
end

-- 生成Lua枚举定义
local function generate_enum_lua(enums)
    local lines = {
        "-- Generating enum.lua from proto/common/enum.proto",
        "-- Generate time: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "",
        "local M = {}"
    }
    
    for _, enum in ipairs(enums) do
        table.insert(lines, "")
        if enum.comment ~= "" then
            table.insert(lines, "-- " .. enum.comment)
        end
        table.insert(lines, "M." .. enum.name .. " = {")
        
        for _, value in ipairs(enum.values) do
            local line = string.format("    %s = %d,", value.name, value.value)
            if value.comment ~= "" then
                line = line .. string.format("    -- %s", value.comment)
            end
            table.insert(lines, line)
        end
        
        table.insert(lines, "}")
    end
    
    table.insert(lines, "")
    table.insert(lines, "return M")
    
    return table.concat(lines, "\n")
end

-- 生成错误码定义
local function generate_error_lua(enums)
    local lines = {
        "-- Generating error.lua from proto/common/error.proto",
        "-- Generate time: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "",
        "local M = {}"
    }

    for _, enum in ipairs(enums) do
        if enum.name == "ErrorCode" then
            table.insert(lines, "")
            if enum.comment ~= "" then
                table.insert(lines, "-- " .. enum.comment)
            end
            table.insert(lines, "M.ErrorCode = {")
            
            -- 添加错误码映射
            for _, value in ipairs(enum.values) do
                local line = string.format("    %s = %d,", value.name, value.value)
                if value.comment ~= "" then
                    line = line .. string.format("    -- %s", value.comment)
                end
                table.insert(lines, line)
            end
            
            table.insert(lines, "}")
            
            -- 添加错误码描述映射
            table.insert(lines, "")
            table.insert(lines, "-- error code description mapping")
            table.insert(lines, "M.ErrorMessage = {")
            for _, value in ipairs(enum.values) do
                local message = value.comment ~= "" and value.comment or value.name
                local line = string.format("    [%d] = \"%s\",", value.value, message)
                table.insert(lines, line)
            end
            table.insert(lines, "}")
            
            break
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "return M")
    
    return table.concat(lines, "\n")
end

-- 生成消息定义
local function generate_message_lua(enums)
    local lines = {
        "-- Generating message.lua from proto/common/message.proto",
        "-- Generate time: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "",
        "local M = {}"
    }

    for _, enum in ipairs(enums) do
        if enum.name == "MessageID" then
            table.insert(lines, "")
            if enum.comment ~= "" then
                table.insert(lines, "-- " .. enum.comment)
            end
            table.insert(lines, "M.MessageID = {")
            
            -- 添加消息ID映射
            for _, value in ipairs(enum.values) do
                local line = string.format("    %s = %d,", value.name, value.value)
                if value.comment ~= "" then
                    line = line .. string.format("    -- %s", value.comment)
                end
                table.insert(lines, line)
            end
            
            table.insert(lines, "}")
            
            break
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "return M")
    
    return table.concat(lines, "\n")
end

-- 主函数
local function main()
    -- 读取enum.proto文件
    local enum_content = read_file("proto/common/enum.proto")
    if not enum_content then
        return false
    end
    
    -- 读取error.proto文件
    local error_content = read_file("proto/common/error.proto")
    if not error_content then
        return false
    end
    
    -- 读取message.proto文件
    local message_content = read_file("proto/common/message.proto")
    if not message_content then
        return false
    end
    
    -- 解析枚举定义
    local enum_enums = parse_enums(enum_content)
    local error_enums = parse_enums(error_content)
    local message_enums = parse_enums(message_content)
    
    -- 生成Lua代码
    local enum_lua = generate_enum_lua(enum_enums)
    local error_lua = generate_error_lua(error_enums)
    local message_lua = generate_message_lua(message_enums)
    
    -- 确保目录存在
    os.execute("mkdir -p lualib")
    
    -- 写入文件
    local ok1 = write_file("lualib/enum.lua", enum_lua)
    local ok2 = write_file("lualib/error.lua", error_lua)
    local ok3 = write_file("lualib/message.lua", message_lua)
    
    return ok1 and ok2 and ok3
end

-- 执行生成
if main() then
    print("Generated enum.lua, error.lua and message.lua successfully")
else
    print("Failed to generate lua files")
    os.exit(1)
end 