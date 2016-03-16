local JSON = require "cjson.safe"

local postData = ngx.req.get_post_args()

local FIND_STR = "Application_Info = {"
local MAX_LINE = 1000

local SYS_CONF_PATH = '/sysconfig/system_config.lua'
local APP_CONFIG_PATH = '/appconfig/config_'
local ACCESS_PHARSE_FILE_PATH = '/access_pharse_'
local LOG_PHARSE_FILE_PATH = '/log_pharse_'

-- 复制相关的文件和目录  默认复制default的相关设置
function copy_file_and_dir(app_name)
	-- app_config配置文件
	local app_config_name = LuaPath .. APP_CONFIG_PATH .. app_name .. '.lua'
	local default_cfg_name = LuaPath .. APP_CONFIG_PATH .. 'default.lua'

	local f_default = io.open(default_cfg_name, 'r')
	local f_write = io.open(app_config_name, 'w')
	local file_str = f_default:read('*a') or ''
	f_write:write(file_str)

	f_write:close()
	f_default:close()

	-- access_pharse文件
	local access_name = LuaPath .. ACCESS_PHARSE_FILE_PATH .. app_name .. '.lua'
	local default_acc_name = LuaPath .. ACCESS_PHARSE_FILE_PATH .. 'default.lua'

	f_default = io.open(default_acc_name, 'r')
	f_write = io.open(access_name, 'w')
	file_str = f_default:read('*a') or ''
	f_write:write(file_str)

	f_write:close()
	f_default:close()

	-- log_pharse文件
	local log_name = LuaPath .. LOG_PHARSE_FILE_PATH .. app_name .. '.lua'
	local default_log_name = LuaPath .. LOG_PHARSE_FILE_PATH .. 'default.lua'

	f_default = io.open(default_log_name, 'r')
	f_write = io.open(log_name, 'w')
	file_str = f_default:read('*a') or ''
	f_write:write(file_str)

	f_write:close()
	f_default:close()

	-- rules目录和文件
	local dir_path = RulePath .. '/' .. app_name
	local default_dir_path = RulePath .. '/default'
	os.execute('mkdir ' .. dir_path)

	for _, file in pairs(Rules_Files) do
		local default_copy_path = default_dir_path .. '/' .. file
		local copy_file_path = dir_path .. '/' .. file

		
		f_default = io.open(default_copy_path, 'r')
		f_write = io.open(copy_file_path, 'w')
		file_str = f_default:read('*a') or ''
		f_write:write(file_str)

		f_write:close()
		f_default:close()
	end
end

-- 更新appinfo的配置文件
function update_appinfo_file(host_name, app_name)
	file_name = LuaPath .. SYS_CONF_PATH

	-- 获取文件内容
	file = io.open(file_name, "r")
	local file_str = ""
	local output_str = '    ["'..host_name..'"] = ' .. '"' .. app_name .. '",\n'
	file:seek("set")

	for line in file:lines() do
		file_str = file_str .. line .. '\n'
		if line == FIND_STR then
			file_str = file_str .. output_str
		end
	end
	
	file:close()

	-- 进行文件写操作
	file = io.open(file_name, "w")
	file:write(file_str)
	file:close()
end

-- 更新appinfo信息
function update_app_info(postData)
	local host_name = postData['host_name']
	local app_name = postData['app_name']
	if not host_name then
		return "setappinfo阶段，host_name参数为空"
	elseif not app_name then
		return "setappinfo阶段，app_name参数为空"
	elseif Application_Info[host_name] then
		ngx_log("warn", "Application_Info[host_name] 信息： " .. Application_Info[host_name])
		return "setappinfo阶段，已经存在该域名的应用，不能重复设置"
	else
		Application_Info[host_name] = app_name
		
		-- 更新文件信息
		update_appinfo_file(host_name, app_name)

		--复制相关的文件和目录信息
		copy_file_and_dir(app_name)
		return nil
	end

	return nil
end



-- 调用
if not postData then
	errmsg = "setappinfo阶段, post请求参数格式不正确, 请检查!"
	ngx_log("error", errmsg)
	response = errmsg
	
	ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
	say(response)
else
	local suc = update_app_info( postData )
	if suc then
		response = "setappinfo操作失败. 原因: "  ..  suc
		
		ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
		say(response)
	else
		response = "setappinfo操作成功."
		say(response)
	end
end

