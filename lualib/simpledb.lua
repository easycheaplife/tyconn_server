local skynet = require "skynet"

local connection = {}    -- 数据库连接池
local database = {}     -- 数据存储
local connection_id = 0  -- 连接ID计数器

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level-1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

local function db_query(db, key)
    if not db then
        return nil
    end
    return db[key]
end

local function db_update(db, key, value)
    if not db then
        return false
    end
    db[key] = value
    return true
end

local db = {}

function db.connect(conf)
    connection_id = connection_id + 1
    local id = connection_id
    connection[id] = database
    skynet.error(string.format("Database connected (id = %d) %s", id, dump(conf)))
    return id
end

function db.disconnect(id)
    connection[id] = nil
end

function db.get(id, key)
    local db = connection[id]
    return db_query(db, key)
end

function db.set(id, key, value)
    local db = connection[id]
    return db_update(db, key, value)
end

function db.incr(id, key)
    local db = connection[id]
    local value = (db_query(db, key) or 0) + 1
    db_update(db, key, value)
    return value
end

-- 添加一些辅助方法
function db.exists(id, key)
    local db = connection[id]
    return db[key] ~= nil
end

function db.del(id, key)
    local db = connection[id]
    if not db then
        return false
    end
    db[key] = nil
    return true
end

function db.keys(id, pattern)
    local db = connection[id]
    if not db then
        return {}
    end
    local result = {}
    for k, _ in pairs(db) do
        if not pattern or k:match(pattern) then
            table.insert(result, k)
        end
    end
    return result
end

function db.flushall(id)
    local db = connection[id]
    if not db then
        return false
    end
    for k, _ in pairs(db) do
        db[k] = nil
    end
    return true
end

-- 调试用：打印数据库内容
function db.dump(id)
    local db = connection[id]
    if not db then
        return "No such connection"
    end
    return dump(db)
end

return db 