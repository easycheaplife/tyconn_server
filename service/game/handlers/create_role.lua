local skynet = require "skynet"
local pb = require "pb"
local logger = require "logger"

local M = {}

function M.handle(client_id, msg)
    -- 解码基础请求
    local ok, base_request = pcall(pb.decode, "common.BaseRequest", msg)
    if not ok then
        logger.error("Failed to decode base request: %s", base_request)
        return nil
    end

    -- 解码请求
    local ok, request = pcall(pb.decode, "command.C2GCreateRoleRequest", base_request.payload)
    if not ok then
        logger.error("Failed to decode create role request: %s", request)
        return nil
    end

    -- 验证参数
    if not request.name or request.name == "" then
        return {
            code = pb.enum("common.ErrorCode", "ERROR_CODE_INVALID_NAME"),
            message = "角色名不能为空"
        }
    end

    -- 创建角色
    local response = skynet.call(skynet.self(), "lua", "create_role", 
        request.token,
        request.name,
        request.gender,
        request.job
    )
    
    -- 构造基础响应
    local base_response = {
        session = base_request.session,
        errorCode = response.code,
        errorMsg = response.message
    }
    
    -- 如果成功，添加payload
    if response.code == pb.enum("common.ErrorCode", "ERROR_CODE_SUCCESS") then
        local ok, payload = pcall(pb.encode, "command.G2CCreateRoleResponse", response)
        if ok then
            base_response.payload = payload
        else
            logger.error("Failed to encode create role response: %s", payload)
        end
    end
    
    -- 编码基础响应
    local ok, encoded = pcall(pb.encode, "common.BaseResponse", base_response)
    if not ok then
        logger.error("Failed to encode base response: %s", encoded)
        return nil
    end
    
    return encoded
end

return M 