local JSON       = require "cjson.safe"
local ngx_shared = ngx.shared

local request_data = ngx.var.request_body
local postData     = JSON.decode(request_data)
local response     = ""
local global_conf_dict = ngx_shared['global']
local file_path = "/appconfig/config_"


-- 更新配置的时候也要同步更新配置文件
function update_conf_file(application_type, global_conf)
	file_name = LuaPath .. file_path .. application_type .. '.lua'
	ngx_log("warn", "配置文件路径: " .. file_name)
	local file_str = ''
	result = false
	if type(global_conf) ~= 'table' then
		result = false
		return result, "conset阶段同步配置文件: " .. file_name .. "失败"
	else
		file_str = table2str(global_conf)
		file_str = file_str .. "All_Conf = {\n"
		--添加AllConfInfo信息
		for k, v in pairs(global_conf) do
			file_str = file_str .. "\t['" .. k .. "'] = " .. k ..",\n" 
		end
		file_str = file_str .. "}\n"

		--写入文件 TODO 异常错误处理
		file = io.open(file_name, "w+")
		file:write(file_str)
		file:close()

		ngx_log("warn", "配置文件配置信息: " .. file_str)
		result = true
		return result, nil
	end	
end

-- 更新共享内存的app_conf
function update_app_conf( postData )
	local find_host = postData['host']
	if not find_host then
		return nil, "confset阶段失败. 原因: 没有获取到host参数，不能获取修改应用类型 " 
	end
	--根据host参数  读取shared_dict中配置信息
	local application_type = get_application_type_by_params(find_host)

	local global_conf, err = global_conf_dict:get(application_type .. "conf")
	err = err or ""
	if not global_conf then
		ngx_log("warn", "confset阶段获取" .. application_type .. "配置信息失败. 原因： " .. err)
		return nil, "confset阶段获取" .. application_type .. "配置信息失败. 原因： " .. err
	end
	global_conf = JSON.decode(global_conf)

	for k, v in pairs(postData) do
		if k ~= 'host' then
			global_conf[k] = v
		end
		
	end

	local suc, err = global_conf_dict:set(application_type .. "conf", JSON.encode(global_conf))
	if not suc then
		return nil, "confset阶段设置" ..  application_type .. "配置信息失败. 原因： " .. err
	else
		suc, err = update_conf_file(application_type, global_conf)
		if not suc then
			ngx_log("warn", "confset阶段" .. application_type .. "同步配置文件信息失败. 原因： " .. err)
			return nil, "confset阶段" .. application_type .. "同步配置文件信息失败. 原因： " .. err
		else
			return suc, nil
		end
	end
end

-- 调用
if not postData then
	errmsg = "confset阶段, post请求参数格式不正确, 请检查!"
	request_data = request_data or ""
	ngx_log("error", errmsg)
	response = errmsg
else
	local suc, err = update_app_conf( postData )
	if not suc then
		err = err or ""
		response = "confset失败. 原因: "  ..  err
	else
		response = "confset操作成功."
	end
end

say(response)