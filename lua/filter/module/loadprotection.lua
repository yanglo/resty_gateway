-- 负载保护
local JSON           = require "cjson.safe"
local ngx_shared     = ngx.shared
local ngx_value      = ngx.var
local modulename     = "loadprotectionModule"
local req_dict_name  = "req_store"
local conn_dict_name = "conn_store"
local host           = ngx.var.host
local ip             = get_client_ip()
local global_key     = "global"
local varnish_dict   = ngx_shared[global_key]

local _M = {
	_VERSION = "0.0.1"
}
local mt = {
	__index = _M
}

function _M:new(loadprotect_dict_name, global_conf)
	local loadprotect_dict = ngx_shared[loadprotect_dict_name]

    local self = {
    	loadprotect_dict = loadprotect_dict,
        loadprotect_conf = global_conf['LoadProtection_Conf'],
    }
    return setmetatable(self, mt)
end

function _M:loadprotection()
	if self.loadprotect_conf['avr_speed']['flag'] then
		--  仅统计这些状态码的返回的平均响应时间
		local statistics_status = {200, 301, 302, 304, }
		local cur_status        = ngx.var.status
		local status_flag       = false

		for k, v in pairs(statistics_status) do
			if tonumber(cur_status) == tonumber(v) then
				status_flag = true
				break
			end
		end
		if status_flag then
			--响应时间过载保护
			local response_time = ngx_value.upstream_response_time or ngx_value.request_time or 0
			response_time = tonumber(response_time) or 0
			response_time = response_time * 1000.0

			--一个定时器删除sys_overload_string
			local time_flag = self.loadprotect_dict:get("time_flag" .. host) or 0
			if time_flag == 0 then
				self.loadprotect_dict:delete("sys_overload_string" .. host)
				self.loadprotect_dict:set("time_flag" .. host, 1, self.loadprotect_conf['avr_speed']['time'])
			end

			local resp = {}
			local resp_string = self.loadprotect_dict:get("sys_overload_string" .. host) or ""
			--一次性写入
			if resp_string == "" then
				resp["count"] = 1
				resp["time"]  = response_time
				self.loadprotect_dict:set("sys_overload_string" .. host, JSON.encode(resp), self.loadprotect_conf['avr_speed']['time'])
			else
				resp = JSON.decode(resp_string)
				resp["count"] = resp["count"] + 1
				resp["time"] = resp["time"] + response_time
				self.loadprotect_dict:set("sys_overload_string" .. host, JSON.encode(resp), self.loadprotect_conf['avr_speed']['time'])
			end

			local total_count = resp["count"] or 1  --错误防止
			local total_time  = resp["time"] or 0
			
			local ave_speed = total_time / total_count
			
			if ave_speed > self.loadprotect_conf['avr_speed']['speed'] then
				--进行降级
				ngx_log("warn", "访问host: " .. host .. " 处理时间过长. 当前速度： " .. ave_speed .. "ms/req, total_count:" .. total_count .. ", total_time: "..total_time)
				varnish_dict:set("varnish_downgrade" .. host, 1)
				return
			else
				--正常系统
				varnish_dict:set("varnish_downgrade" .. host, 0)
			end
		end
	end
	

	if self.loadprotect_conf['status_code']['flag'] then
		--状态码  过载保护
		local Overload_Status_Code = {502,}
		local cur_status = ngx.var.status

		for k, v in pairs(Overload_Status_Code) do
			if tonumber(cur_status) == tonumber(v) then
				self.loadprotect_dict:add("sys_overload" .. host .. tostring(cur_status), 0, self.loadprotect_conf['status_code']['time'])
				self.loadprotect_dict:incr("sys_overload" .. host .. tostring(cur_status), 1)

				local cur_status_count = tonumber(self.loadprotect_dict:get("sys_overload" .. host .. tostring(cur_status))) or 0
				if cur_status_count > self.loadprotect_conf['status_code']['count'] then
					--进行降级
					ngx_log("warn", "访问host: " .. host .. " 连续出现状态码"..cur_status)
					varnish_dict:set("varnish_downgrade" .. host, 1)
					return
				else
					--正常系统
					varnish_dict:set("varnish_downgrade" .. host, 0)
				end
			end
		end
	end

	if self.loadprotect_conf['request_count']['flag'] then
		--吞吐量过载保护
		local req_dict = ngx_shared[req_dict_name]
		local req_count = req_dict:get(host .. "excess") or 0
		if req_count > self.loadprotect_conf['request_count']['count'] * 1000 then
			ngx_log("warn", "吞吐量达到限定值，访问host: " .. host .. " 当前超出吞吐量：" .. req_count)
			varnish_dict:set("varnish_downgrade" .. host, 1)
			return
		else
			varnish_dict:set("varnish_downgrade" .. host, 0)
		end
	end


	if self.loadprotect_conf['conn_count']['flag'] then
		--并发量过载保护
		local conn_dict = ngx_shared[conn_dict_name]
		local conn_count = conn_dict:get(ip .. host) or 0
		if not self.loadprotect_conf['conn_count']['count'] then
			return
		end

		if conn_count > self.loadprotect_conf['conn_count']['count'] then
			ngx_log("warn", "并发数达到限定值，访问host: " .. host .. " 当前并发量：" .. conn_count)
			varnish_dict:set("varnish_downgrade" .. host, 1)
			return
		else
			varnish_dict:set("varnish_downgrade" .. host, 0)
		end
	end
end

return _M