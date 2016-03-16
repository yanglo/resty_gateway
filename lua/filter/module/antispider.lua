local modulename = "antispiderModule"

local JSON                = require "cjson.safe"
local ngx_shared          = ngx.shared
local access_analysis_key = "access_analysis_key"

local access_dict = ngx_shared[access_analysis_key]
local expire_time = 60 * Time_diff + 10

local months_number = {
	["Jan"] = 1,
    ["Feb"] = 2,
    ["Mar"] = 3,
    ["Apr"] = 4,
    ["May"] = 5,
    ["Jun"] = 6,
    ["Jul"] = 7,
    ["Aug"] = 8,
    ["Sep"] = 9,
    ["Oct"] = 10,
    ["Nov"] = 11,
    ["Dec"] = 12
}

local Filter_Type = {
	"IP_Spider",
	"UA_Spider",
	"WindowInfo_Spider",
	"Refferer_Spider",
}

local _M = {
	_VERSION = "0.0.1"
}
local mt = {
	__index = _M
}

function _M:new(ip_dict_name, referrer_dict_name, window_dict_name, global_conf)
	local ip_dict       = ngx_shared[ip_dict_name]
	local referrer_dict = ngx_shared[referrer_dict_name]
	local window_dict   = ngx_shared[window_dict_name]
	local log_flag      = global_conf['Statistics_Conf']['spider_log'] and global_conf['Statistics_Conf']['flag']

    local self = {
        ip_dict       = ip_dict,
        referrer_dict = referrer_dict,
        window_dict   = window_dict,
        global_conf   = global_conf,
        log_flag      = log_flag,
    }

    return setmetatable(self, mt)
end

--反爬虫， 根据IP频率判断
function _M:_ipSpider()
	local spider_conf = self.global_conf['Spider_Conf']['ip_spider']

	if spider_conf['flag'] then
		local ip                        = get_client_ip()
		local host                      = ngx.var.host
		local timestamp, last_timestamp = get_timestamp(os.time())

		--开始过滤
		local req, _  = self.ip_dict:get(ip .. host)
		if not req then
			self.ip_dict:set(ip .. host, 1, spider_conf['time'])
		else
			if req > spider_conf['count'] then
				if self.log_flag then
					--开启爬虫日志记录
					local spider_key = table.concat({host, Filter_Type[1], "-", timestamp})
					local spider_sum = access_dict:get(spider_key)
					
					if spider_sum == nil then
						access_dict:set(spider_key, 1, expire_time)
					else
						access_dict:incr(spider_key, 1)
					end

					spider_sum = access_dict:get(spider_key)
				end

				if spider_conf['process'] == "forbidden" then
					ngx_log("warn", "当前IP: " .. ip  .. ", 访问host: " .. host .. ", 检测为IpSpider, 返回403.")
					return ngx.exit(ngx.HTTP_FORBIDDEN)
				elseif spider_conf['process'] == "verify" then
					ngx_log("warn", "当前IP: " .. ip  .. ", 访问host: " .. host .. ", 检测为IpSpider, 输出验证码页面.")
					return ngx.redirect("/verify?spider_type=ip_spider")
				end
			else
				self.ip_dict:incr(ip .. host, 1)
			end
		end
	end
end

--反爬虫  根据UserAgnet 过滤掉相关useragent的信息
function _M:_uaSpider()
	local spider_conf = self.global_conf['Spider_Conf']['ua_spider']

	if spider_conf['flag'] then
		local timestamp, last_timestamp = get_timestamp(os.time())

		local application_type = get_application_type()
		local uarules = read_rule(application_type .. '/useragents')
		local host = ngx.var.host

		local ua = ngx.var.http_user_agent
		if ua ~= nil then
			for _,rule in pairs(uarules) do
				--单行模式匹配
				if rule ~= "" and ngx.re.find(ua, rule, "isjo") then
					if self.log_flag then
						local spider_key = table.concat({host, Filter_Type[2], "-", timestamp})
						local spider_sum = access_dict:get(spider_key)
						
						if spider_sum == nil then
							access_dict:set(spider_key, 1, expire_time)
						else
							access_dict:incr(spider_key, 1)
						end

						spider_sum = access_dict:get(spider_key)
					end

					ngx_log("warn", "当前UserAgent: ".. ua  .. ", 访问host: " .. host .. ", 匹配到UA规则： ".. rule .. "判定为UaSpider")
					ngx.exit(ngx.HTTP_FORBIDDEN)
				end
			end
		end
	end
end

--反爬虫   根据referrer进行判断 ip+referer作为key  
function _M:_referrerSpider()
	local spider_conf = self.global_conf['Spider_Conf']['referrer_spider']

	if spider_conf['flag'] then
		local referrer                  = ngx.var.http_referer or "noreferer"
		local ip                        = get_client_ip()
		local host                      = ngx.var.host
		local timestamp, last_timestamp = get_timestamp(os.time())
		local referrer_key              = {
			referrer,
			ip,
			host,
		}

		local referrer_key_json = JSON.encode(referrer_key)
		self.referrer_dict:add(referrer_key_json, 0, spider_conf['time'])
		self.referrer_dict:incr(referrer_key_json, 1)

		local referrer_count = self.referrer_dict:get(referrer_key_json) or 0

		if referrer_count > spider_conf['count'] then
			if self.log_flag then
				local spider_key = table.concat({host, Filter_Type[4], "-", timestamp})
				local spider_sum = access_dict:get(spider_key)
				
				if spider_sum == nil then
					access_dict:set(spider_key, 1, expire_time)
				else
					access_dict:incr(spider_key, 1)
				end

				spider_sum = access_dict:get(spider_key)
			end
			
			if spider_conf['process'] == "forbidden" then
				ngx_log("warn", "当前IP: " .. ip .. ", 访问host: " .. host .. ", 访问referer: " .. referrer  .. ", 判定为RefSpider, 返回403")
				return ngx.exit(ngx.HTTP_FORBIDDEN)
			elseif spider_conf['process'] == "verify" then
				ngx_log("warn", "当前IP: " .. ip .. ", 访问host: " .. host .. ", 访问referer: " .. referrer  .. ", 判定为RefSpider, 输出验证码页面.")
				return ngx.redirect("/verify?spider_type=ref_spider&refer=" .. referrer)
			end
		end
	end
end

--反爬虫  根据访问的时间间隔是否固定进行判断
function _M:_windowSpider()
	local spider_conf = self.global_conf['Spider_Conf']['windowinfo_spider']

	if spider_conf['flag'] then
		local host = ngx.var.host
		local timestamp, last_timestamp = get_timestamp(os.time())
		local access_time = ngx.var.time_local
		access_time = string.split(access_time, ' ')[1]
		-- 25/Sep/2015:00:54:45
		local D  = tonumber(string.split(access_time, '/')[1])
		local M  = tonumber(months_number[string.split(access_time, '/')[2]])
		local Y  = tonumber(string.split(string.split(access_time, '/')[3], ':')[1])
		local H  = tonumber(string.split(access_time, ":")[2])
		local MM = tonumber(string.split(access_time, ":")[3])
		local SS = tonumber(string.split(access_time, ":")[4])

		local fmt_time = os.time{year=Y, month=M, day=D, hour=H,min=MM,sec=SS}
		local ip = get_client_ip()
		local window_info = {
			fmt_time,
		}

		local window_dict_value = self.window_dict:get(ip .. host)
		if not window_dict_value then
			table.insert(window_info, 0)
			table.insert(window_info, 1)
			self.window_dict:set(ip  .. host, JSON.encode(window_info), spider_conf['time'])
		else
			local before_window = JSON.decode(window_dict_value)
			if before_window[3] > spider_conf['count'] then
				if self.log_flag then
					local spider_key = table.concat({host, Filter_Type[4], "-", timestamp})
					local spider_sum = access_dict:get(spider_key)
					
					if spider_sum == nil then
						access_dict:set(spider_key, 1, expire_time)
					else
						access_dict:incr(spider_key, 1)
					end

					spider_sum = access_dict:get(spider_key)
				end
				
				if spider_conf['process'] == "forbidden" then
					ngx_log("warn", "当前IP: " .. ip .. ", 判定为WindowSpider, 返回403")
					return ngx.exit(ngx.HTTP_FORBIDDEN)
				elseif spider_conf['process'] == "verify" then
					ngx_log("warn", "当前IP: " .. ip .. ", 判定为WindowSpider, 输出验证码页面.")
					return ngx.redirect("/verify?spider_type=window_spider")
				end
			else
				local diff_time = tonumber(fmt_time) - tonumber(before_window[1])
				local distance_time = math.abs(tonumber(diff_time) - tonumber(before_window[2]))

				if distance_time < spider_conf['diff'] then
					table.insert(window_info, diff_time)
					table.insert(window_info, before_window[3] + 1)
					self.window_dict:set(ip .. host, JSON.encode(window_info), spider_conf['time'])
				else
					table.insert(window_info, diff_time)
					table.insert(window_info, 1)
					self.window_dict:set(ip .. host, JSON.encode(window_info), spider_conf['time'])
				end
			end
		end
	end
end

function _M:antiSpiderFilter()
	if if_admin_url() then
		return
	end
	
	self:_ipSpider()
	self:_uaSpider()
	self:_referrerSpider()
	self:_windowSpider()
end

return _M