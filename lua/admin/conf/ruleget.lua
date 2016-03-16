local rulepath = RulePath
local response = ""

-- 获取参数
local data      = get_method_and_params()
local rule_file = data['params']['rulefile']
local find_host = data['params']['host']

-- 根据host参数  读取shared_dict中配置信息
local application_type = get_application_type_by_params(find_host)

-- 读取配置文件
file = io.open(rulepath.."/"..application_type.."/"..rule_file, "r")
if not file then
	ngx_log("error", "没有找到相关文件: "..application_type.."/"..rule_file)
	response = "没有找到相关文件: "..application_type.."/"..rule_file
else
	for line in file:lines() do
		response = response .. line .. '\n'
	end
	file:close()
end

say(response)