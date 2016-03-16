local JSON                   = require "cjson.safe"
local ngx_shared             = ngx.shared
local access_analysis_key    = "access_analysis_key"
local access_dict            = ngx_shared[access_analysis_key]
local expire_time            = 60 * Time_diff + 10
-- timestamp, last_timestamp = get_timestamp(os.time())

local _M = {
    _VERSION = "0.0.1"
    }
local mt = {
    __index = _M
}

function _M:new(access_old_art_dict,access_person_arts_dict, other_behavior_dict, limited_url_file, expired_time, max_art_id, ignore_count)
    local access_old_art = ngx_shared[access_old_art_dict]
    local access_person_arts = ngx_shared[access_person_arts_dict]
    local other_behavior = ngx_shared[other_behavior_dict]
    if not access_old_art then
        ngx.say(access_old_art_dict," not found")
        return nil, "shared dict not found"
    end
    if not access_person_arts then
        ngx.say(access_person_arts_dict, " not found")
        return nil, "shared dict not found"
    end
    if not other_behavior then
        ngx.say(other_behavior_dict, " not found")
        return nil, "shared dict not found"
    end
    local self = {
        access_old_art = access_old_art,
        access_person_arts = access_person_arts,
        other_behavior = other_behavior,
        limited_url_file = limited_url_file,
        expired_time = expired_time,
        max_art_id = max_art_id,
        ignore_count = ignore_count,
    }
    return setmetatable(self, mt)
end

function _M:is_limitedurl(url)
    --判断是否在limitedurl清单内
    local limited_url_file = self.limited_url_file
    local limited_urls =  read_rule(limited_url_file)
    for i,line in pairs(limited_urls) do
        for each in string.gmatch(line, "[^%s]+") do
            local matched,err = ngx.re.match(url, each, 'isjo')
            if matched then
                if matched[0] == url or matched["postfix"] then
                    return true,url
                end
            end
        end
    end
    return false,url
end

function _M:get_url_info()
    --获取用户UUID
    local Uuid = get_header_by_name("Uuid")
    --获取用户IP
    local req_ip = get_client_ip()
    --获取请求uri
    local req_url = get_url(false)
    local unescape_req_url = get_url(true)
    --获取请求方法和参数
    local method_params = get_method_and_params()
    local url_info = {
        ip =  req_ip,
        Uuid = Uuid,
        url = unescape_req_url,
        method = method_params['method'],
        params = method_params['params'],
    }
    return url_info
end

--判断url行为
local function behavior_congnition(url, max_art_id)
   local url_behavior = {
        access_old_art = "/article/(?<art_id>\\d+)$",
        access_my_arts = "/user/my/articles/?(\\d+)?$",
        access_other_arts = "/user/\\d+/articles$",
    }

    for key,value in pairs(url_behavior) do
        local matched,err = ngx.re.match(url, value, "isjo")
        if matched then
            if not matched["art_id"] then
                return "access_person_arts"
            else
                if tonumber(matched["art_id"]) < max_art_id then
                    return key
                end
            end
        else
            if err then
                ngx_log("warn", "error")
                return "other_behavior"
            end
        end
    end
    return "other_behavior"
end

--url行为分析
local function behavior_analysis(behaviors, limited_count)
    local flag = true
    local msg = "success"
    local art_detail_count = behaviors.access_old_art or 0
    local person_arts_count = behaviors.access_person_arts or 0
    local other_behavior_count = behaviors.other_behavior or 0
    local behavior_count = art_detail_count + person_arts_count + other_behavior_count

    if behavior_count > limited_count then
        --存在访问过自己帖子或者他人帖子列表
        if behavior_count == art_detail_count then
            flag = false
            msg = "all behaviors is access old article"

        elseif person_arts_count > 0 then
            if art_detail_count/person_arts_count > 30 then
                flag = false
                msg = "(access old article="..art_detail_count..")/(access my or other article list="..person_arts_count..") > 30"
            end
        else
            --todo:it depends
            if other_behavior_count > 0 and art_detail_count/other_behavior_count > 30 then
                flag = false
                msg = "access old article frequently("..art_detail_count.."/"..other_behavior_count..")"
            end
        end
    end

    return flag, msg
end

--检查url行为是否合法
function _M:behavior_validate(uuid, url)
    local flag = true
    local msg = "success"
    local access_old_art = self.access_old_art
    local access_person_arts = self.access_person_arts
    local other_behavior = self.other_behavior

    local access_old_art_count = access_old_art:get(uuid)
    local access_person_arts_count = access_person_arts:get(uuid)
    local other_behavior_count = other_behavior:get(uuid)
    local cur_behavior = behavior_congnition(url, self.max_art_id)
    if cur_behavior == "access_old_art" then
        if access_old_art_count then
            access_old_art:incr(uuid, 1)
            access_old_art_count = access_old_art_count + 1
        else
            access_old_art:set(uuid, 1, self.expired_time)
            access_old_art_count = 1
        end
    elseif cur_behavior == "access_person_arts" then
        if access_person_arts_count then
            access_person_arts:incr(uuid, 1)
            access_person_arts_count = access_person_arts_count + 1
        else
            access_person_arts:set(uuid, 1, self.expired_time)
            access_person_arts_count = 1
        end
    else
        if other_behavior_count then
            other_behavior:incr(uuid, 1)
            other_behavior_count = other_behavior_count + 1
        else
            other_behavior:set(uuid, 1, self.expired_time)
            other_behavior_count = 1
        end
    end
    local behaviors = {
        access_old_art = access_old_art_count,
        access_person_arts = access_person_arts_count,
        other_behavior = other_behavior_count,
    }
    if cur_behavior == "access_old_art" then
        flag, msg = behavior_analysis(behaviors, self.ignore_count)
    end
    return flag, msg
end

function _M:url_filter(app_type)
    local timestamp, last_timestamp = get_timestamp(os.time())
    local url_info = self:get_url_info()
    local ip = url_info['ip']
    local uuid = url_info['Uuid'] or "nouuid"
    if type(uuid) == "table" then
        uuid = JSON.encode(uuid)
    end
    local url = url_info['url']
    local method = url_info['method']
    local is_limited,limited_url = self:is_limitedurl(url)
    if is_limited then
        ngx_log("warn","limited url : "..limited_url)

        --start log
        local filter_key = table.concat({app_type, Filter_Type[6], "-", timestamp})
        local filter_sum = access_dict:get(filter_key)
        
        if filter_sum == nil then
            access_dict:set(filter_key, 1, expire_time)
        else
            access_dict:incr(filter_key, 1)
        end

        return ngx.exit(403)
    end

    local flag, msg = self:behavior_validate(uuid,url)
    if flag then
        return
    else
       ngx_log("warn", "该访问可能是非法访问("..msg..")， 返回Forbidden")

        --start log
        local filter_key = table.concat({app_type, Filter_Type[5], "-", timestamp})
        local filter_sum = access_dict:get(filter_key)
        
        if filter_sum == nil then
            access_dict:set(filter_key, 1, expire_time)
        else
            access_dict:incr(filter_key, 1)
        end

       return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
end

return _M