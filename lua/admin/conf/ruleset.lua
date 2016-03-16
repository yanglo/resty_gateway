local rulepath = RulePath
local response = ""

--获取参数
local data      = get_method_and_params()
local rule_file = data['params']['rulefile']
local find_host = data['params']['host']
local rule_data = data['params']['ruledata']

--根据host名  读取shared_dict中配置信息
local application_type = get_application_type_by_params(find_host)

--读取配置文件
file = io.open(rulepath.."/" .. application_type .. "/" ..rule_file, "w+")
if not file then
	response = "文件不存在"
else
	--写入文件
	file:write(rule_data)
	file:close()
	response = "操作成功"
end
say(response)

