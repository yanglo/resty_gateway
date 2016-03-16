require "commonlib.common"
local modulename  = "wafModule"
local ngxmatch    = ngx.re.find
local get_headers = ngx.req.get_headers
local unescape    = ngx.unescape_uri
local method      = ngx.req.get_method()

local _M = {
	_VERSION = "0.0.1"
}

local mt = {
	__index = _M
}

function _M:new()
    local self = {}
    return setmetatable(self, mt)
end

--url过滤
function _M:urls()
    local application_type = get_application_type()
	local urlrules = read_rule(application_type .. '/urls')
	for _,rule in pairs(urlrules) do
        if rule ~="" and ngxmatch(ngx.var.request_uri,rule,"isjo") then
            ngx_log("error", ngx.var.request_uri .. " 匹配URL规则： " .. rule)
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
    end
    return false
end

--get参数过滤
function _M:gets()
    local application_type = get_application_type()
	local getrules = read_rule(application_type .. '/gets')
	local getargs  = ngx.req.get_uri_args()
    if not getargs then
        return
    end
	for _, rule in pairs(getrules) do
		for k, val in pairs(getargs) do
			if type(val) == 'table' then
				local t={}
                for k,v in pairs(val) do
                    if v == true then
                        v=""
                    end
                    table.insert(t,v)
                end
                data=table.concat(t, " ")
			else
				data = val
			end

			if data and type(data) ~= 'boolean' and rule ~= "" and ngxmatch(unescape(data),rule,"isjo") then
				ngx_log("error", ngx.var.request_uri .. " 匹配GET规则： " .. rule)
				ngx.exit(ngx.HTTP_FORBIDDEN)
				return true
			end
		end
	end
	return false
end

--post参数过滤  
function _M:posts()
    local application_type = get_application_type()
	local postrules = read_rule(application_type .. '/posts')
    local postargs = ngx.req.get_post_args()
    local data     = ""
	for _,rule in pairs(postrules) do
        for k, v in pairs(postargs) do
            if type(v) == 'table' then
                if type(v[1]) == "boolean" then
                    return
                end
                data=table.concat(v, ", ")
            else
                data = v
            end

            if data and type(data) ~= 'boolean' and rule ~= "" and ngxmatch(unescape(data),rule,"isjo") then
                ngx_log("error", ngx.var.request_uri .. "的数据：" .. data .. "，匹配POST规则： " .. rule)
                ngx.exit(ngx.HTTP_FORBIDDEN)
                return true
            end
        end
    end
    return false
end


--cookie过滤
function _M:cookie()
    local ck = ngx.var.http_cookie
    if not ck then
        return
    end

    local application_type = get_application_type()
    cookierules = read_rule(application_type .. '/cookies')
    for _,rule in pairs(cookierules) do
        if rule ~="" and ngxmatch(ck,rule,"isjo") then
            ngx_log('warn',ngx.var.request_uri .. ", 当前cookie:" .. ck .. "匹配COOKIE规则：" .. rule)
            ngx.exit(ngx.HTTP_FORBIDDEN)
        	return true
        end
    end
    return false
end


--waf功能函数
function _M:WAF()
	self:urls()
    if method == "POST" then
        self:posts()
    else
        self:gets()
    end
    self:cookie()
end

return _M