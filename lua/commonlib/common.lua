--公共函数库
require     "sysconfig.system_config"
JSON        = require "cjson.safe"
get_headers = ngx.req.get_headers
luapath     = LuaPath
rulepath    = RulePath
--日志时间间隔参数
Time_diff = 5

--获取客户端ip
function get_client_ip()
	local IP = get_headers()["X-Real-IP"]
	
	if IP == nil then
		IP = ngx.var.remote_addr
	elseif IP == nil then
		IP = "unknown"
	end

	if type(IP) == "table" then
		IP = JSON.encode(IP)
	end
	return IP
end

--获取相关header数据
function get_header_by_name(header_name)
	ret = get_headers()[header_name]
	if ret == nil then
		-- ngx_log("warn", "没有相关header数据", header_name)
	end
	return ret
end

--获取请求url（unescape表示是否转义）
function get_url(unescape)
    local url = ngx.var.uri
    if unescape then
        url = ngx.unescape_uri(url)
    end
    if url ==  nil then
        ngx_log("error","url获取失败")
        return nil,"failed to get url"
    end
    return url
end

--获取请求方法和参数
function get_method_and_params()
    --获取请求方法
    local req_method = ngx.req.get_method()
    --获取参数
    local req_params = nil
    if req_method == nil then
        ngx_log("error", "请求方法获取失败")
        return nil,"failed to get method"
    elseif string.lower(req_method) == 'get' then
        req_params = ngx.req.get_uri_args()
    elseif string.lower(req_method) == 'post' then
        req_params = ngx.req.get_post_args()
    else
        req_params = ""
    end
    return {method=req_method, params=req_params}
end

--读取配置文件
function read_rule(var)
	file = io.open(rulepath.."/"..var, "r")
	if file == nil then
		return
	end
	t = {}
	for line in file:lines() do
		table.insert(t, line)
	end
	file:close()
	return (t)
end
--新增hash函数,,
function hash(garyvalue)
	if garyvalue ~= nil then
		val = 1
		for s in string.gmatch(garyvalue, ".") do
			temp = string.byte(s)
			val = val + temp
		end
		return val
	else
		return 0
	end
end
--输出错误日志的工具函数
function ngx_log(type, errmsg)
	if type == "warn" then
		ngx.log(ngx.WARN, errmsg)
		-- file = io.open("../logs/test.txt", "a+")
		-- io.output(file)
		-- io.write(errmsg .. "\n")
		-- io.close(file)
	elseif type == "error" then
		ngx.log(ngx.ERR, errmsg)
	elseif type == "info" then
		ngx.log(ngx.INFO, errmsg)
	elseif type == "debug" then
		ngx.log(ngx.DEBUG, errmsg)
	else
		ngx.log(ngx.DEBUG, errmsg) --默认debug模式
	end
end


--写文件工具函数
function write(logfile, msg)
	local fd = io.open(logfile, "ab")
	if fd == nil then
		ngx_log("error", "open and write file error")
		return
	end
	fd:write(msg)
	fd:flush()
	fd:close()
end

--写入到日志文件中， 用于后期统计
function write_log(method,url,data,ruletag)
    if IfRecordLog then
        local realIp = get_client_ip()
        local ua = ngx.var.http_user_agent
        local servername=ngx.var.server_name
        local time=ngx.localtime()
        if ua  then
            line = realIp.." ["..time.."] \""..method.." "..servername..url.."\" \""..data.."\"  \""..ua.."\" \""..ruletag.."\"\n"
        else
            line = realIp.." ["..time.."] \""..method.." "..servername..url.."\" \""..data.."\" - \""..ruletag.."\"\n"
        end
        local filename = LogPath..'/'..servername.."_"..ngx.today().."_sec.log"
        write(filename,line)
    end
end


--封装say函数， 便于后期生产模式切换
function say(msg)
	ngx.say(msg)
end

--转换table为JSON格式字符串，
function convert_table(table_content)
	return JSON.encode(table_content)
end

--获取table keys
function get_table_keys(table_content)
	local t = {}
	for k, _ in table_content do
		table.insert(t, k)
	end
	return (t)
end

--获取table values
function get_table_values(table_content)
	local t = {}
	for _, v in table_content do
		table.insert(t, v)
	end
	return (t)
end


--新增字符串分割函数
function string.split(str, delimiter)
	if str==nil or str=='' or delimiter==nil then
		return nil
	end

    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end


--获取当前时间和上一时间戳
function get_timestamp(cur_time)
	local timestamp = cur_time
	--上次5分钟的时间戳
	local last_timestamp = timestamp - 60 * Time_diff

	--格式转换
	timestamp = os.date("%Y-%m-%d %H:%M:%S", timestamp)
	last_timestamp = os.date("%Y-%m-%d %H:%M:%S", last_timestamp)

	local MM   = tonumber(string.split(timestamp, ":")[2])
	local last_MM   = tonumber(string.split(last_timestamp, ":")[2])

	if last_MM % Time_diff == 0 then
		last_timestamp = string.split(last_timestamp, ":")[1] .. ":" .. tonumber(string.split(last_timestamp, ":")[2]) .. ":00"
	else
		min = tonumber(string.split(last_timestamp, ":")[2]) - last_MM % Time_diff
		last_timestamp = string.split(last_timestamp, ":")[1] .. ":" .. min .. ":00"
	end

	if MM % Time_diff == 0 then
		timestamp = string.split(timestamp, ":")[1] .. ":" .. tonumber(string.split(timestamp, ":")[2]) .. ":00"
	else
		min = tonumber(string.split(timestamp, ":")[2]) - MM % Time_diff
		timestamp = string.split(timestamp, ":")[1] .. ":" .. min .. ":00"
	end
	--返回值： 当前时间戳, 上个时间戳
	return timestamp, last_timestamp
end

--根据host获取application类型
function get_application_type()
	local host = ngx.var.host
	if not Application_Info[host] then
		-- ngx_log("warn", "没有找到对应的application类型，加载默认default配置")
		return "default"
	else
		-- ngx_log("warn", "加载".. Application_Info[host] .."配置")
		return Application_Info[host]
	end
end


--根据参数获取application类型
function get_application_type_by_params(param)
	for k, v in pairs(Application_Info) do
		if param == v then
			return param
		end
	end
	return "default"
end


-- 判断是否是管理员接口
function if_admin_url()
	local url = ngx.var.uri
	for _, v in pairs(Admin_URL) do
		if url == v then
			return true
		end
	end
	return false
end

--  table2str的内部调用
function table2str_inner(table_val)
	local ret = ''
	if type(table_val) == 'string' then
		ret =  "'" .. table_val .. "'"
	elseif type(table_val) == 'table' then
		for k, v in pairs(table_val) do
			ret = ret .. k .. ' = '
			if type(v) == 'string' then
				ret = ret .. "'" .. v .. "',\n"
			elseif type(v) == 'table' then
				ret = ret .. '{\n'
				ret = ret .. table2str_inner(v)
				ret = ret .. '},\n'
			else
				ret = ret .. tostring(v) .. ",\n"
			end
		end
	else
		ret = tostring(table_val)
	end
	return ret
end

--  将table转换成字符串形式
function table2str(table_val) 
	local ret = ''
	if type(table_val) == 'string' then
		ret =  "'" .. table_val .. "'"
	elseif type(table_val) == 'table' then
		for k, v in pairs(table_val) do
			ret = ret .. k .. ' = '
			if type(v) == 'string' then
				ret = ret .. "'" .. v .. "'\n"
			elseif type(v) == 'table' then
				ret = ret .. '{\n'
				ret = ret .. table2str_inner(v)
				ret = ret .. '}\n'
			else
				ret = ret .. tostring(v) .. "\n"
			end
		end
	else
		ret = tostring(table_val)
	end
	return ret
end

