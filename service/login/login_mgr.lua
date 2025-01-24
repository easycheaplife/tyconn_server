local skynet = require "skynet"
local logger = require "logger"
local jwt = require "jwt"
local cluster = require "skynet.cluster"

local M = {}
local config = {}

-- 获取token过期时间
function M.get_token_expire()
    return config.jwt_expire
end

-- 初始化配置
function M.init(conf)
    if not conf.jwt_secret then
        logger.error("Missing jwt_secret in configuration")
        return false
    end
    
    config = {
        jwt_secret = conf.jwt_secret,
        jwt_expire = conf.jwt_expire or 3600,
        version_min = conf.version_min,
        version_latest = conf.version_latest,
        version_force_update = conf.version_force_update == "true"
    }
    
    logger.debug("Login manager initialized with config:")
    logger.debug("  jwt_expire = %d", config.jwt_expire)
    logger.debug("  version_min = %s", config.version_min or "not set")
    logger.debug("  version_latest = %s", config.version_latest or "not set")
    logger.debug("  version_force_update = %s", tostring(config.version_force_update))
    
    return true
end

-- 比较版本号
local function compare_version(v1, v2)
    local function parse_version(v)
        local major, minor, patch = string.match(v, "(%d+)%.(%d+)%.(%d+)")
        return {
            tonumber(major) or 0,
            tonumber(minor) or 0,
            tonumber(patch) or 0
        }
    end
    
    local v1_parts = parse_version(v1)
    local v2_parts = parse_version(v2)
    
    for i = 1, 3 do
        if v1_parts[i] > v2_parts[i] then
            return 1
        elseif v1_parts[i] < v2_parts[i] then
            return -1
        end
    end
    return 0
end

-- 检查版本
function M.check_version(version)
    if not version then
        logger.error("Missing version in request")
        return false
    end
    
    -- 检查最低版本要求
    if config.version_min and compare_version(version, config.version_min) < 0 then
        logger.warn("Version too old: client=%s, required=%s", version, config.version_min)
        return false
    end
    
    -- 检查强制更新
    if config.version_force_update and config.version_latest and 
       compare_version(version, config.version_latest) < 0 then
        logger.warn("Force update required: client=%s, latest=%s", version, config.version_latest)
        return false
    end
    
    logger.debug("Version check passed: %s", version)
    return true
end

-- 验证账号密码
function M.verify_account(account, password)
    -- 这里应该调用数据库服务验证账号密码
    -- 目前简化处理，只验证测试账号
    if account:match("^test") then
        return {
            account = account
        }
    end
    return nil
end

-- 生成token
function M.generate_token(user_info)
    -- 设置token有效期
    local claims = {
        account = user_info.account,
        iss = "tyconn_login",
        exp = os.time() + config.jwt_expire,
        iat = os.time()
    }
    
    local ok, token = pcall(jwt.encode, claims, config.jwt_secret)
    if not ok then
        logger.error("Failed to generate token: %s", token)
        return nil
    end
    
    return token
end

return M 