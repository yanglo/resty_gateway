require "commonlib.common"
local modulename = "whitelistModule"

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
-- 白名单判断， 读取whitelist文件
function _M:whiteListFilter()
	local application_type = get_application_type()
	local whitelist        = read_rule(application_type .. '/whitelists')
	local ip               = get_client_ip()
	
	for _, line in pairs(whitelist) do
		if ip == line then
			return true
		end
	end
	return false
end

return _M