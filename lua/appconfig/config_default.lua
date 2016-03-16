-- 默认application配置

-- 黑名单开关  配置为true代表打开黑名单开关  
-- 具体配置规则在../rules/default/blacklists
BlackList_Flag = true

-- 白名单开关
WhiteList_Flag = true

-- waf开关 以下分别代表是否开启urls/cookies/gets参数/posts参数过滤  
-- 对应规则文件分别是urls/cookies/gets/posts
WAF_Conf = {
	flag         = true,
	url_flag     = true,
	cookies_flag = true,
	gets_flag    = true,
	posts_flag   = true,
}

-- 爬虫开关  分别代表IP/UA/referrer/windowinfo爬虫   UA爬虫需要设置相关规则文件useragents 默认不开启refferrer爬虫检测
-- process标识判定为爬虫后的处理方式， 可选值：forbidden(返回403), verify(返回验证码页面)
Spider_Conf = {
	flag = true,
	ip_spider = {
		flag    = true,
		count   = 200,
		time    = 10,
		process = "forbidden",    --可选值：forbidden, verify
	},
	ua_spider = {
		flag = true,
	},
	referrer_spider = {
		flag    = false,
		count   = 100,
		time    = 10,
		process = "forbidden",
	},
	windowinfo_spider = {
		flag    = true,
		count   = 100,
		time    = 30,
		diff    = 1,
		process = "forbidden",
	},
}

-- 限流相关设置  若开启限流则需要设置根据ip的吞吐量限制， 根据host的吞吐量限制， 根据ip的并发量限制
Traffic_Conf = {
	flag           = true,
	req_ip_count   = 50,
	req_ip_burst   = 20,
	req_host_count = 300,
	req_host_burst = 100,
	conn_ip_count  = 200,
	conn_ip_burst  = 100,
}

-- 过载保护相关配置  分4种机制进行过载保护：请求平均速度， 错误状态码(500, 502, 503), 吞吐量, 并发量
-- 默认关闭降级
LoadProtection_Conf = {
	flag = true,
	upstream = "default",
	avr_speed = {
		flag  = true,
		time  = 10,
		speed = 15000,
	},
	status_code = {
		flag  = true,
		time  = 10,
		count = 300,
	},
	request_count = {
		flag  = true,
		count = 80,
	},
	conn_count = {
		flag  = true,
		count = 250,
	},
}

-- 灰度配置， 由于灰度是强应用相关的，因此只提供不同的灰度方式， 具体的策略需要应用自己提供
-- 灰度类型提供3种， hash方式， redis方式， new方式(新用户灰度)
Gary_Conf = {
	flag      = false,
	gary_type = "hash",
}

-- 统计日志记录配置   默认开启所有日志记录 
Statistics_Conf = {
	flag              = true,
	spider_log        = true,
	connection_log    = true,
	request_count_log = true,
	response_time_log = true,
	status_code_log   = true,
}

--所有配置项  方便将配置信息保存在redis中
All_Conf = {
	['BlackList_Flag']      = BlackList_Flag,
	['WhiteList_Flag']      = WhiteList_Flag,
	['WAF_Conf']            = WAF_Conf,
	['Spider_Conf']         = Spider_Conf,
	['Traffic_Conf']        = Traffic_Conf,
	['LoadProtection_Conf'] = LoadProtection_Conf,
	['Gary_Conf']           = Gary_Conf,
	['Statistics_Conf']     = Statistics_Conf,
}