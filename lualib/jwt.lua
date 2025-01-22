local cjson = require "cjson"
local crypt = require "skynet.crypt"

local jwt = {}

-- Base64URL编码
local function base64url_encode(str)
    local s = crypt.base64encode(str)
    s = string.gsub(s, "+", "-")
    s = string.gsub(s, "/", "_")
    s = string.gsub(s, "=+$", "")
    return s
end

-- Base64URL解码
local function base64url_decode(str)
    local s = str
    s = s .. string.rep("=", 4 - ((#s - 1) % 4) - 1)
    s = string.gsub(s, "-", "+")
    s = string.gsub(s, "_", "/")
    return crypt.base64decode(s)
end

-- 签名
local function sign(message, key, alg)
    if alg ~= "HS256" then
        error("Unsupported algorithm: " .. tostring(alg))
    end
    local hashkey = crypt.hashkey(key)
    return base64url_encode(crypt.hmac_hash(hashkey, message))
end

-- 验证签名
local function verify_signature(message, signature, key, alg)
    if alg ~= "HS256" then
        error("Unsupported algorithm: " .. tostring(alg))
    end
    local expected_sig = sign(message, key, alg)
    return signature == expected_sig
end

-- 编码JWT
function jwt.encode(claims, key, alg)
    alg = alg or "HS256"
    
    -- 创建头部
    local header = {
        typ = "JWT",
        alg = alg
    }
    
    -- 编码头部和载荷
    local segments = {
        base64url_encode(cjson.encode(header)),
        base64url_encode(cjson.encode(claims))
    }
    
    -- 计算签名
    local signing_input = table.concat(segments, ".")
    local signature = sign(signing_input, key, alg)
    table.insert(segments, signature)
    
    return table.concat(segments, ".")
end

-- 解码JWT
function jwt.decode(token, key, verify)
    if not token then
        return nil, "token is nil"
    end
    
    if not key then
        return nil, "key is nil"
    end
    
    local segments = {}
    for segment in token:gmatch("[^%.]+") do
        table.insert(segments, segment)
    end
    
    if #segments ~= 3 then
        return nil, string.format("invalid token format: expected 3 segments, got %d", #segments)
    end
    
    -- 解码头部
    local ok, header = pcall(cjson.decode, base64url_decode(segments[1]))
    if not ok then
        return nil, "Invalid header"
    end
    
    -- 解码载荷
    local ok, claims = pcall(cjson.decode, base64url_decode(segments[2]))
    if not ok then
        return nil, "Invalid claims"
    end
    
    -- 验证签名
    if verify then
        local signing_input = segments[1] .. "." .. segments[2]
        if not verify_signature(signing_input, segments[3], key, header.alg) then
            return nil, "Invalid signature"
        end
        
        -- 验证过期时间
        local now = os.time()
        if claims.exp and claims.exp < now then
            return nil, "Token expired"
        end
    end
    
    return claims
end

return jwt