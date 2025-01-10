local pb = require "pb"
local protoc = require "protoc"
local skynet = require "skynet"

local M = {}

-- 创建 protoc 实例并设置导入路径
local function create_protoc(proto_dir)
	local p = protoc.new()
	p.include_imports = true
	p:addpath(proto_dir)
	return p
end

function M.load(proto_file, proto_dir)
	skynet.error("Loading proto file:", proto_file)
	local f = io.open(proto_file, "r")
	if not f then
		skynet.error("Failed to open proto file:", proto_file)
		return false
	end
	local content = f:read("*a")
	f:close()

	-- 创建带有正确导入路径的 protoc 实例
	local p = create_protoc(proto_dir)
	local ok, err = pcall(p.load, p, content)
	if not ok then
		skynet.error("Failed to load proto file:", proto_file, "error:", err)
		return false
	end
	skynet.error("Successfully loaded proto file:", proto_file)
	return true
end

function M.load_directory(proto_dir)
	skynet.error("Loading proto files from directory:", proto_dir)
	
	-- 先加载 common 目录下的基础 proto 文件
	local common_files = io.popen('ls ' .. proto_dir .. '/common/*.proto')
	if common_files then
		for file in common_files:lines() do
			if not M.load(file, proto_dir) then
				common_files:close()
				return false
			end
		end
		common_files:close()
	end
	
	-- 再加载其他目录的 proto 文件
	local dir = io.popen('ls ' .. proto_dir .. '/game/*.proto ' .. proto_dir .. '/command/*.proto')
	if not dir then
		skynet.error("Failed to open proto directory:", proto_dir)
		return false
	end

	local success = true
	for file in dir:lines() do
		if not M.load(file, proto_dir) then
			dir:close()
			return false
		end
	end
	dir:close()
	return success
end

return M
