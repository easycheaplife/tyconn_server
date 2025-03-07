local skynet = require "skynet"
local logger = require "logger"
local equip_service = require "services.equip_service"
local user_session_service = require "services.user_session_service"

local M = {}

-- 已有的定时任务...

-- 检查装备过期
function M.check_equipment_expire()
    logger.info("Starting equipment expiration check")
    
    -- 获取在线用户列表
    local online_users = user_session_service.get_all_online_user_ids()
    
    -- 如果没有在线用户，直接返回
    if not online_users or #online_users == 0 then
        return
    end
    
    -- 检查每个在线用户的装备过期情况
    local equip_service = require "services.equip_service"
    for _, user_id in ipairs(online_users) do
        equip_service.check_equipment_expire(user_id)
    end
end

-- 检查装备等级升级
function M.check_equipment_level_upgrades()
    logger.info("Checking equipment level upgrades")
    
    local equip_service = require "services.equip_service"
    local count = equip_service.check_equipment_level_upgrades()
    
    logger.info("Completed %d equipment level upgrades", count)
    
    -- 设置下一次检查
    skynet.timeout(60 * 100, M.check_equipment_level_upgrades)  -- 1分钟检查一次
end

-- 清理过期邮件
function M.check_expired_mails()
    local mail_service = require "services.mail_service"
    mail_service.delete_expired_mails()
    
    -- 每小时检查一次
    skynet.timeout(3600 * 100, M.check_expired_mails)
end

-- 注册所有定时任务
function M.register_all_jobs()
    -- 已有的定时任务注册...
    
    -- 装备过期检查
    skynet.timeout(60 * 100, M.check_equipment_expire)  -- 服务器启动1分钟后开始第一次检查
    
    -- 装备等级升级检查
    skynet.timeout(30 * 100, M.check_equipment_level_upgrades)
    
    -- 清理过期邮件
    skynet.timeout(3600 * 100, M.check_expired_mails)
    
    logger.info("Timer jobs registered")
end

return M 