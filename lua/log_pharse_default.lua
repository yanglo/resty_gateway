local loadprotLib         = require "filter.module.loadprotection"
local ngx_shared          = ngx.shared
local access_analysis_key = "access_analysis_key"
local ngx_value           = ngx.var
local mysql               = require "resty.mysql"
local local_servername    = ngx.var.hostname
local host                = ngx.var.host

-- 根据host名  取全局配置信息
local application_type = get_application_type()
local global_conf_dict = ngx_shared['global']
local global_conf, err = global_conf_dict:get(application_type .. "conf")
if not global_conf then
	err = err or ''
	ngx_log("warn", "取" .. application_type .. "配置信息失败. 原因： " .. err)
	-- ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end
global_conf = JSON.decode(global_conf)

-- 该文件要放在log_by_lua_file中  并发数减1
function conn_leaving()
    local ctx = ngx.ctx
    local lim = ctx.limit_conn
    if lim then
        local latency = tonumber(ngx.var.request_time)
        local key = ctx.limit_conn_key
        if not key then
        	return
        end
        local conn, err = lim:leaving(key, latency)
        if not conn then
            return
        end
    end
end

-- 函数调用
conn_leaving()

--------------------
local load_protection = loadprotLib:new("loadprotect_count",  global_conf)
load_protection:loadprotection()

local access_dict = ngx_shared[access_analysis_key]
local expire_time = 60 * Time_diff + 10
timestamp, last_timestamp = get_timestamp(os.time())

-- 记录日志开关
local log_flag =  global_conf['Statistics_Conf']['flag']
local request_count_log = log_flag and global_conf['Statistics_Conf']['request_count_log']
local response_time_log = log_flag and global_conf['Statistics_Conf']['response_time_log']
local status_code_log = log_flag and global_conf['Statistics_Conf']['status_code_log']
local spider_log = log_flag and global_conf['Statistics_Conf']['spider_log']
local connection_log = log_flag and global_conf['Statistics_Conf']['connection_log']

-- 统计函数定义
-- 状态码情况统计
function error_code_log()
	local cur_status = ngx.var.status
	local status_key = table.concat({application_type , "-", cur_status, "-", timestamp})
	local status_sum = access_dict:get(status_key)
	
	if not status_sum then
		access_dict:set(status_key, 1, expire_time)
	else
		access_dict:incr(status_key, 1)
	end
end

-- 响应时间日志
function resp_time_log()
	local response_time = ngx_value.upstream_response_time or ngx_value.request_time or 0
    
	response_time = tonumber(response_time) or 0
	response_time = response_time * 1000.0


	local resp_key_count = table.concat({application_type , "-", "all" .. "-" .. "avg_resp_time_count", "-", timestamp})
	local resp_key_time = table.concat({application_type , "-", "all" .. "-" .. "avg_resp_time_time", "-", timestamp})
	
	access_dict:add(resp_key_count, 0, expire_time)
	access_dict:incr(resp_key_count, 1)

	access_dict:add(resp_key_time, 0, expire_time)
	access_dict:incr(resp_key_time, response_time)
end

-- 请求量统计
function access_url_log()
	local status_key = table.concat({application_type , "-", "all", "-", timestamp})
	local status_sum = access_dict:get(status_key)
	
	if not status_sum then
		access_dict:set(status_key, 1, expire_time)
	else
		access_dict:incr(status_key, 1)
	end
end


-- 开启相应日志记录
if status_code_log then
	error_code_log()
end

if response_time_log then 
	resp_time_log()
end

if request_count_log then
	access_url_log()
end


-- 写入上次的key
function insert_log(premature, timestamp, last_timestamp)
	-- db 连接
	local db = nil
	local timestamp_key = timestamp .. application_type
	
	local if_has_timestamp = access_dict:get(timestamp_key)
	if not if_has_timestamp then
		access_dict:add(timestamp_key, 1, expire_time)
	else
		access_dict:incr(timestamp_key, 1)
	end
	if_has_timestamp = access_dict:get(timestamp_key)

	if if_has_timestamp == 1 and log_flag then
		db, err = mysql:new()
		if not db then
		    ngx_log("error", "初始化日志统计数据库失败. 原因: " .. err)
		end

		db:set_timeout(1000) -- 1 sec

		local ok, err, errno, sqlstate = db:connect{
		    host = DBConf_Analysis.host,
		    port = DBConf_Analysis.port,
		    database = DBConf_Analysis.database,
		    user = DBConf_Analysis.user,
		    password = DBConf_Analysis.password,
		}

		if not ok then
			ngx_log("error", "连接日志统计数据库失败. 原因: " .. err)
			return nil, "连接日志统计数据库失败."
		end
	
        -- 上次状态码信息入库
        if status_code_log then
        	-- 需要统计的状态码
        	local Status_Code = {
				200,
				301,
				302,
				304,
				403,
				404,
				499,
				500,
				502,
				503,
			}
        	for _, value in pairs(Status_Code) do
				local last_status_key = table.concat({application_type , "-", value, "-", last_timestamp})
				local last_status_count = access_dict:get(last_status_key) or 0
			
				-- db入库
				local res, err, errno, sqlstate = db:query("insert into errorcode(server_ip, status_code, happen_count, log_time, application_type) "
								.. "values ('" .. local_servername .. "', " .. value .. ", " .. last_status_count .. ", '" .. last_timestamp.."', '"..application_type.."')")
				if not res then
					ngx_log("error", "插入数据库errorcode失败，应用类型: " .. application_type)
				end
			end 
        end
		
		-- 上次响应时间入库
		if response_time_log then
			-- 所有all
			local last_resp_key_count = table.concat({application_type , "-", "all" .. "-" .. "avg_resp_time_count", "-", last_timestamp})
			local last_resp_key_time = table.concat({application_type , "-", "all" .. "-" .. "avg_resp_time_time", "-", last_timestamp})

			local total_count = tonumber(access_dict:get(last_resp_key_count) or 1)
			local total_time = tonumber(access_dict:get(last_resp_key_time) or 0)
			local ave_speed = total_time / total_count

			-- db入库
			local res, err, errno, sqlstate = db:query("insert into requesttime(server_ip, request_url, request_time, log_time, application_type) "
							.. "values ('" .. local_servername .. "', 'all', " .. ave_speed .. ", '" .. last_timestamp .."', '"..application_type .. "')")
			if not res then
				ngx_log("error", "插入数据库requesttime失败，应用类型: " .. application_type)
			end
		end

		-- 上次请求量日志入库
		if request_count_log then
			local last_req_count_key = table.concat({application_type , "-", "all", "-", last_timestamp})
			local last_req_count = access_dict:get(last_req_count_key) or 0

			--db入库
			local res, err, errno, sqlstate = db:query("insert into req_count(server_ip, request_type, request_count, log_time, application_type) "
							.. "values ('" .. local_servername .. "', 'all', " .. last_req_count .. ", '" .. last_timestamp .."', '"..application_type .. "')")
			if not res then
				ngx_log("error", "插入数据库req_count失败，应用类型: " .. application_type)
			end
		end
		
		-- 上次爬虫扫描情况， 非法请求情况入库
		if spider_log then
			Filter_Type = {
				"IP_Spider",
				"UA_Spider",
				"WindowInfo_Spider",
				"Refferer_Spider",
			}

			for _, value in pairs(Filter_Type) do
				local last_filter_key = table.concat({host, value, "-", last_timestamp})
				local last_filter_count = access_dict:get(last_filter_key) or 0

				local res, err, errno, sqlstate = db:query("insert into spider_count(server_ip, filter_type, filter_count, log_time, application_type) "
								.. "values ('" .. local_servername .. "', '" .. value .. "', " .. last_filter_count .. ", '" .. last_timestamp .."', '"..application_type .. "')")
				if not res then
					ngx_log("error", "插入数据库spider_count失败，应用类型: " .. application_type)
				end
			end
		end

		-- 每隔5分钟的并发量入库
		if connection_log then
			local conn_dict_name = "conn_store"
			local conn_dict = ngx_shared[conn_dict_name]

			local connection_count = conn_dict:get(host) or 0

			local res, err, errno, sqlstate = db:query("insert into connection_count(server_ip, connection_count, log_time, application_type) "
							.. "values ('" .. local_servername .. "', " .. connection_count .. ", '" .. last_timestamp .."', '"..application_type .. "')")
			if not res then
				ngx_log("error", "插入数据库connection_count失败，应用类型: " .. application_type)
			end
		end
	end
end

-- 日志入库
ngx.timer.at(0, insert_log, timestamp, last_timestamp)



