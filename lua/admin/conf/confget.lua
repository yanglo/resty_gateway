local JSON             = require "cjson.safe"
local ngx_shared       = ngx.shared
local global_conf_dict = ngx_shared['global']

-- 根据host名  读取shared_dict中配置信息
local data      = get_method_and_params()
local find_host = data['params']['host']

-- 根据host参数  读取shared_dict中配置信息
local application_type = get_application_type_by_params(find_host)
local response = ""

local global_conf, err = global_conf_dict:get(application_type .. "conf")
err = err or ""
if not global_conf then
	ngx_log("warn", "confget阶段取" .. application_type .. "配置信息失败. 原因： " .. err)
	response = "获取" .. application_type .. "配置信息失败. 原因： " .. err
else
	response = global_conf
end

say(response)