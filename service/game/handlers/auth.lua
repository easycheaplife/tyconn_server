local skynet = require "skynet"
local pb = require "pb"
local logger = require "logger"
local jwt = require "jwt"

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end

    -- 解码认证请求
    local ok, request = pcall(pb.decode, "command.C2GAuthRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode auth request: %s", request)
        return nil
    end

    -- 验证token
    local claims, err = jwt.decode(request.token, jwt_secret, true)
    if not claims then
        local response = {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_TOKEN_INVALID"),
            message = err
        }
        
        -- 编码认证响应
        local ok, payload = pcall(pb.encode, "command.G2CAuthResponse", response)
        if not ok then
            logger.error("Failed to encode auth response: %s", payload)
            return nil
        end
        
        -- 构造基础响应
        local base_response = {
            session = base_request.session,
            errorCode = response.code,
            errorMsg = response.message,
            payload = payload
        }
        
        -- 编码基础响应
        local ok, encoded = pcall(pb.encode, "common.BaseResponse", base_response)
        if not ok then
            logger.error("Failed to encode base response: %s", encoded)
            return nil
        end
        
        return encoded
    end

    -- 认证成功
    local response = {
        code = pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS"),
        message = "Authentication successful",
        username = claims.name
    }
    
    -- 编码认证响应
    local ok, payload = pcall(pb.encode, "command.G2CAuthResponse", response)
    if not ok then
        logger.error("Failed to encode auth response: %s", payload)
        return nil
    end
    
    -- 构造基础响应
    local base_response = {
        session = base_request.session,
        errorCode = response.code,
        errorMsg = response.message,
        payload = payload
    }
    
    -- 编码基础响应
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", base_response)
    if not ok then
        logger.error("Failed to encode base response: %s", encoded)
        return nil
    end
    
    return encoded
end

return M 