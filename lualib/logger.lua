local skynet = require "skynet"

local M = {}

function M.log(fmt, ...)
    local t = os.date("%Y-%m-%d %H:%M:%S")
    skynet.error(string.format("[%s] " .. fmt, t, ...))
end

return M 