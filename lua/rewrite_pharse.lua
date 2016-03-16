local JSON               = require "cjson.safe"
local ngx_shared         = ngx.shared
local application_config = "appconfig.config_"
local global_conf_dict   = ngx_shared['global']
local host               = ngx.var.host

-- 测试使用    去除所有写请求
-- local url_request = ngx.var.request
-- local method = string.sub(url_request, 1, 4)
-- if not if_admin_url() then	
-- 	if method == "POST" then
-- 	    ngx.exit(500)
-- 	end
-- end

-- 根据host名加载配置文件
local application_type = get_application_type()
local config_url       = application_config .. application_type
local global_conf      = require(config_url)

-- 将配置信息设置到ngx_shared_dict中
function set_conf_to_shared()
	local conf_flag = global_conf_dict:get(application_type .. "flag") or 0
	if conf_flag == 0 then
		local res, err = global_conf_dict:set(application_type .. "flag", 1)
		if not res then
			ngx_log("warn", "设置shared_dict标志位失败. 原因： " .. err)
			return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
		res, err = global_conf_dict:set(application_type .. "conf", JSON.encode(All_Conf))
		if not res then
			ngx_log("warn", "设置shared_dict配置信息失败. 原因： " .. err)
			return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
		end
		ngx_log("warn", "设置application_type: " .. application_type .. "设置值："  .. JSON.encode(All_Conf))
	end
end

set_conf_to_shared()