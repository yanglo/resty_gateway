local modulename = "commonRedisModule"
local redis      = require('resty.redis')
local redisInfo  = RedisConf
local _M         = {
    _VERSION = '0.0.1'
}

local mt = {
    __index = _M,
}

function _M:new(conf)
    conf = conf or redisInfo
    local red = redis:new()
    local self = {
        host     = conf.RedisHost,
        port     = conf.RedisPort,
        timeout  = conf.RedisTimeout,
        dbid     = conf.RedisDB,
        idletime = conf.RedisIdletime,
        poolsize = conf.RedisPoolSize,
        redis    = red,
    }
    return setmetatable(self, mt)
end

function _M:connectdb()
    local host  = self.host
    local port  = self.port
    local dbid  = self.dbid
    local red   = self.redis

    if not dbid then dbid = 0 end

    local timeout   = self.timeout 
    if not timeout then 
        timeout = 10000   -- 10s
    end
    red:set_timeout(timeout)

    local ok, err 
    if host and port then
        ok, err = self.redis:connect(host, port)
        if not ok then
            ngx_log("error", "redis error" .. err)
        end
        if ok then return self.redis:select(dbid) end
    end

    return ok, err
end

function _M:keepalivedb()
    local   pool_max_idle_time  = self.idletime --毫秒
    local   pool_size           = self.poolsize --连接池大小

    if not pool_size then pool_size = 1000 end
    if not pool_max_idle_time then pool_max_idle_time = 90000 end
    
    return self.redis:set_keepalive(pool_max_idle_time, pool_size)  
end

return _M
