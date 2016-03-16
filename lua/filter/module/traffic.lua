--限制请求数和并发数
local limit_conn    = require "utils.conn"
local limit_req     = require "utils.req"
local limit_traffic = require "utils.traffic"

local modulename = "trafficModule"
local _M = {
	_VERSION = "0.0.1"
}
local mt = {
	__index = _M
}

function _M:new(req_dict_name, conn_dict_name, global_conf)
    local self = {
    	req_dict_name = req_dict_name,
    	conn_dict_name = conn_dict_name, 
        traffic_conf = global_conf['Traffic_Conf'],
    }

    return setmetatable(self, mt)
end
-- 限制req请求数， 并发数
function _M:trafficSpeed(application_type)
	local lim1, err = limit_req.new(self.req_dict_name, self.traffic_conf['req_host_count'], self.traffic_conf['req_host_burst'])
	local lim2, err = limit_req.new(self.req_dict_name, self.traffic_conf['req_ip_count'], self.traffic_conf['req_ip_burst'])
	local lim3, err = limit_conn.new(self.conn_dict_name, self.traffic_conf['conn_ip_count'], self.traffic_conf['conn_ip_burst'], 0.5)

	local limiters = {lim1, lim2, lim3}

	local host = ngx.var.host
	local ip = get_client_ip()
	local keys = {host, ip .. host, ip .. host}

	local states = {}

	local delay, err = limit_traffic.combine(limiters, keys, states)
	if not delay then
	    if err == "rejected" then
	    	ngx_log("error", "当前访问到达限速标准. 访问host: " .. host)
	        return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	    end
	    ngx_log("error", "traffic模块调用失败. 访问host: " .. host)
	    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
	end

	if lim3:is_committed() then
	    local ctx = ngx.ctx
	    ctx.limit_conn = lim3
	    ctx.limit_conn_key = keys[3]
	end

	if delay > 0 then
	    ngx.sleep(delay)
	end
end

return _M