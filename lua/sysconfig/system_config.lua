--application配置 没有在下面配置的application默认使用default配置
Application_Info = {
	["www.test.com"] = "test",
}

--rules文件配置地址
RulePath = '/home/bot/services/openresty/nginx/conf/openresty_filter/rules'

--lua文件
LuaPath = '/home/bot/services/openresty/nginx/conf/openresty_filter/lua'

--Redis配置 线上统一访问nlb1上的redis
RedisConf = {
	RedisPort     = 6379,
	RedisTimeout  = 1000,
	RedisIdletime = 90000,
	RedisPoolSize = 1000,
	RedisDB       = 5,
	RedisHost     = 'xx.xx.xx.xx',   
}

--统计数据入库数据库， 线上访问t-nlb1的数据库
DBConf_Analysis = {
	 host     = "xx.xx.xx.xx",
     port     = 3306,
     database = "xxx",
     user     = "xxx",
     password = "xxxxxxxx",
}

Admin_URL = {
	"/verify",
	"/admin/conf/get",
	"/admin/conf/set",
	"/admin/conf/ruleget",
	"/admin/conf/ruleset",
	"/admin/conf/getappinfo",
	"/admin/conf/setappinfo",
}

Rules_Files = {
	"blacklists",
	"cookies",
	"garyrules",
	"gets",
	"posts",
	"urls",
	"useragents",
	"whitelists",
}