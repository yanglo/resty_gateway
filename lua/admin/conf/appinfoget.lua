local JSON = require "cjson.safe"
local appinfo = Application_Info
local response = ""
if  not appinfo then
	response = "获取应用信息失败"
else
	response = JSON.encode(appinfo)
end

say(response)