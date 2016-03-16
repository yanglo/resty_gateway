local redisModule = require "utils.redis"
local _M = {
	_VERSION = "0.0.1"
}

local mt = {
	__index = _M
}

function _M:new()
	local redisLib = redisModule:new()
	local ok, err  = redisLib:connectdb()

	if not ok then
		ngx_log("error", "连接灰度redis失败，原因: "..err)
		return
	end

	local self = {
		redisLib = redisLib,
	}

	return setmetatable(self, mt)
end

--uidfile函数
function _M:_garyByRedis(redis_key, user_identify)
	if not user_identify then
		return
	end

	local res, err = self.redisLib.redis:sismember(redis_key, user_identify)
	if not res then
		ngx_log("error", "获取redis相关灰度user_identify值: ".. user_identify .. "失败. " .. err)
		return
	end

	self.redisLib:keepalivedb()

	if res == ngx.null or res == 0 then  --不是集合的成员元素
		return
	elseif res == 1 then  -- 是集合的成员元素
		ngx_log("warn", "进入灰度发布, 实际用户特征: " .. user_identify)
		return ngx.redirect("@gary_env")
	end
end

--根据相关字段hash灰度
function _M:_garyByHash(percent, user_identify)
	--不存在直接返回
	if not user_identify then
		return
	end

	local modvalue = tonumber(hash(user_identify)) % 100
	if modvalue < percent then
		ngx_log("warn", "进入灰度发布, mod值: " .. modvalue .. ", 实际用户特征: " .. user_identify)
		return ngx.redirect("@gary_env")
	else
		return
	end
end

--新用户比较规则进行灰度
function _M:_garyByNew(comp_identify, user_identify)
	if not comp_identify then
	    return
	end
	if not user_identify then
		return
	end
	if tonumber(comp_identify) > tonumber(user_identify) then 
		return
	else
		ngx_log("warn", "进入灰度发布, 比较特征: " .. comp_identify .. ", 实际用户特征:" .. user_identify)
		return ngx.redirect("@gary_env")
	end
	
end

return _M