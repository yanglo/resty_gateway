local JSON             = require "cjson.safe"
local ngx_shared       = ngx.shared
local cur_ip           = get_client_ip()
local host             = ngx.var.host
local ngxmatch         = ngx.re.find
local url              = get_url(true)
local global_conf_dict = ngx_shared['global']
local mysql            = require "resty.mysql"

--根据host名  读取shared_dict中配置信息
local application_type = get_application_type()

local global_conf, err = global_conf_dict:get(application_type .. "conf")
if not global_conf then
	ngx_log("warn", "取" .. application_type .. "配置信息失败. 原因： " .. err)
	ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

global_conf = JSON.decode(global_conf)


--清除相关过滤缓存数据 仅针对爬虫返回为验证码页面的应用生效
function clear_shared()
	local verify_pass = get_method_and_params()['params']['verify'] or "noverify"
	local sp_type = get_method_and_params()['params']['spider_type'] or "notype"
	if verify_pass == "pass" then
		--清除相关记录数据
		if sp_type == "ip_spider" then
			ngx_shared["ip_spider"]:delete(cur_ip .. host)
			ngx_log("warn", "清除ip访问频率内存")
		elseif sp_type == "window_spider" then
			ngx_shared["window_spider"]:delete(cur_ip .. host)
			ngx_log("warn", "清除时间窗口内存")
		elseif sp_type == "ref_spider" then
			local cur_refer = get_method_and_params()['params']['refer']
			local delete_key = {cur_refer, cur_ip, host}
			ngx_shared["referrer_spider"]:delete(JSON.encode(delete_key))
			ngx_log("warn", "清除referer记录内存")
		else
		end
	end
end

--执行清除共享内存
clear_shared()


--自定义获取user_identify函数   用于灰度
function get_user_identify()
	-- your own code
	return nil, "获取user_identify失败!"
end

--引入过滤模块
local whitelistLib  = require "filter.module.whitelist"
local blacklistLib  = require "filter.module.blacklist"
local wafLib        = require "filter.module.waf"
local antiSpiderLib = require "filter.module.antispider"
local trafficLib    = require "filter.module.traffic"
local garyLib       = require "filter.module.garydivision"


--各个模块开关
local whitelist_flag = global_conf['WhiteList_Flag']
local blacklist_flag = global_conf['BlackList_Flag']

local waf_flag        = global_conf['WAF_Conf']['flag']
local spider_flag     = global_conf['Spider_Conf']['flag']
local traffic_flag    = global_conf['Traffic_Conf']['flag']
local loadproc_flag   = global_conf['LoadProtection_Conf']['flag']
local gary_flag       = global_conf['Gary_Conf']['flag']
local statistics_flag = global_conf['Statistics_Conf']['flag']

--白名单过滤
if whitelist_flag then
	local whitelist = whitelistLib:new()
	local isWhite = whitelist:whiteListFilter()
	if not isWhite then
		if blacklist_flag then
			--黑名单直接拒绝访问
			local blacklist = blacklistLib:new()
			blacklist:blackListFilter()
		end

		if waf_flag then
			--WAF过滤
			local waf = wafLib:new()
			waf:WAF()
		end

		if spider_flag then
			--爬虫过滤
			local anti_spider = antiSpiderLib:new("ip_spider", "referrer_spider", "window_spider", global_conf)
			anti_spider:antiSpiderFilter()
		end

		if traffic_flag then
			--限流过滤
			local traffic = trafficLib:new("req_store", "conn_store", global_conf)
			traffic:trafficSpeed()
		end

		if gary_flag then
			--灰度发布
			local garydivision = garyLib:new()
			local gary_type = global_conf['Gary_Conf']['gary_type']

			local user_identify, err = get_user_identify()
			if user_identify then
				if gary_type == 'new' then
					--使用new方式灰度
					local comp_identify = 1000
					garydivision:_garyByNew(comp_identify, user_identify)
				elseif gary_type == 'redis' then
					--使用redis方式灰度
					local redis_key = "gary_default"
					garydivision:_garyByRedis(redis_key, user_identify)
				elseif gary_type == 'hash' then
					--使用hash方式灰度
					local percent = 20
					garydivision:_garyByHash(percent, user_identify)
				end
			else
				err = err or ''
				ngx_log("error", "自定义获取user_identify失败，没有进入灰度流程. 原因: " .. err)
			end
		end
	end
end


--检测是否降级  通过以上所有过滤的请求才检测是否需要降级   
function if_varnish_downgrade()
	local ngx_shared = ngx.shared
	local varnish_dict = ngx_shared["global"]
	local varnish_flag = varnish_dict:get("varnish_downgrade" .. host) or 0
	local cur_backend = ngx.var.backend
	if varnish_flag == 1 then
		if global_conf['LoadProtection_Conf']['upstream'] == 'default' then
			ngx.var.backend = cur_backend
		else
			ngx_log("warn", "default. 该请求进入降级处理流程。url: " .. url)
			ngx.var.backend = global_conf['LoadProtection_Conf']['upstream']
		end
	else
		ngx.var.backend = cur_backend
	end
end

--调用
if_varnish_downgrade()
