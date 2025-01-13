local pb = require "pb"
local protoc = require "protoc"
local skynet = require "skynet"
local logger = require "logger"

local M = {}

-- 创建 protoc 实例并设置导入路径
local function create_protoc(proto_dir)
	local p = protoc.new()
	p.include_imports = true
	p:addpath(proto_dir)
	return p
end

-- 加载单个 proto 文件
function M.load(proto_file, proto_dir)
	logger.info("Loading proto file: %s", proto_file)
	local f = io.open(proto_file, "r")
	if not f then
		logger.error("Failed to open proto file: %s", proto_file)
		return false
	end
	local content = f:read("*a")
	f:close()

	local p = create_protoc(proto_dir)
	local ok, err = pcall(p.load, p, content)
	if not ok then
		logger.error("Failed to load proto file: %s, error: %s", proto_file, err)
		return false
	end
	logger.info("Successfully loaded proto file: %s", proto_file)
	return true
end

-- 检查目录是否存在
local function dir_exists(dir)
	local handle = io.popen('cd "' .. dir .. '" 2>/dev/null && echo "1"')
	if not handle then return false end
	local result = handle:read("*a")
	handle:close()
	return result == "1\n"
end

-- 获取目录下所有 proto 文件
local function get_proto_files(dir)
	local files = {}
	local cmd = string.format('cd "%s" && find . -name "*.proto" 2>/dev/null', dir)
	local handle = io.popen(cmd)
	if not handle then
		logger.error("Failed to execute find command in directory: %s", dir)
		return files
	end
	
	for file in handle:lines() do
		file = string.gsub(file, "^%./", "")
		table.insert(files, dir .. "/" .. file)
	end
	handle:close()
	
	-- 按文件名排序，确保加载顺序一致
	table.sort(files)
	return files
end

-- 加载指定目录下的所有 proto 文件
function M.load_directory(proto_dir)
	logger.info("Loading proto files from directory: %s", proto_dir)
	
	if not proto_dir then
		logger.error("Proto directory not specified")
		return false
	end
	
	if not dir_exists(proto_dir) then
		logger.error("Invalid proto directory: %s", proto_dir)
		return false
	end
	
	-- 获取并加载所有 proto 文件
	local files = get_proto_files(proto_dir)
	if #files == 0 then
		logger.warn("No proto files found in directory: %s", proto_dir)
		return true
	end
	
	-- 按文件名顺序加载所有文件
	for _, file in ipairs(files) do
		if not M.load(file, proto_dir) then
			return false
		end
	end
	
	return true
end

return M
