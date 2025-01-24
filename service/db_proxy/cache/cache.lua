local skynet = require "skynet"
local logger = require "logger"
local const = require "db_proxy.const"

local M = {}

-- LRU缓存实现
local Cache = {}
Cache.__index = Cache

function Cache.new(max_size)
    local self = setmetatable({}, Cache)
    self.max_size = max_size
    self.data = {}
    self.access_time = {}
    self.size = 0
    return self
end

function Cache:get(key)
    local value = self.data[key]
    if value then
        self.access_time[key] = skynet.now()
        return value
    end
    return nil
end

function Cache:set(key, value, expire)
    if self.size >= self.max_size then
        self:evict()
    end
    
    if not self.data[key] then
        self.size = self.size + 1
    end
    
    self.data[key] = value
    self.access_time[key] = skynet.now()
    
    -- 设置过期时间
    if expire then
        skynet.timeout(expire * 100, function()
            if self.data[key] then
                self:remove(key)
            end
        end)
    end
end

function Cache:remove(key)
    if self.data[key] then
        self.data[key] = nil
        self.access_time[key] = nil
        self.size = self.size - 1
    end
end

function Cache:evict()
    local oldest_time = math.huge
    local oldest_key = nil
    
    for key, time in pairs(self.access_time) do
        if time < oldest_time then
            oldest_time = time
            oldest_key = key
        end
    end
    
    if oldest_key then
        self:remove(oldest_key)
    end
end

-- 创建缓存实例
local user_cache = Cache.new(const.CACHE.MAX_CACHE_SIZE)
local token_cache = Cache.new(const.CACHE.MAX_CACHE_SIZE)

-- 用户缓存接口
function M.get_user(account)
    return user_cache:get(account)
end

function M.set_user(account, user_info)
    user_cache:set(account, user_info, const.CACHE.USER_EXPIRE)
end

function M.remove_user(account)
    user_cache:remove(account)
end

-- Token缓存接口
function M.get_token(account)
    return token_cache:get(account)
end

function M.set_token(account, token_info)
    token_cache:set(account, token_info, const.CACHE.TOKEN_EXPIRE)
end

function M.remove_token(account)
    token_cache:remove(account)
end

return M 