require "commonlib.common"
local modulename = "blacklistModule"

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
--白名单判断， 读取blacklist文件
function _M:blackListFilter()
	local application_type = get_application_type()
	local blacklist        = read_rule(application_type .. '/blacklists')
	local ip               = get_client_ip()
	
	for _, line in pairs(blacklist) do
		if ip == line then
			ngx_log("warn", "当前IP: " .. ip .. ", 进入黑名单流程,直接拒绝访问")
			ngx.exit(ngx.HTTP_FORBIDDEN)
		end
	end
end

return _M