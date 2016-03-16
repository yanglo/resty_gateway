require "commonlib.common"
local JSON = require "cjson.safe"

local spider_type = get_method_and_params()['params']['spider_type'] or "nospidertype"
local back_url = 'document.referrer+"'
if spider_type == 'nospidertype' then
    back_url = back_url .. '?verify=pass";'
else
    --ip
    if spider_type == "ip_spider" or spider_type == "window_spider" then
        back_url = back_url .. '?verify=pass&spider_type=' .. spider_type .. '";'
    --referer  ip
    elseif spider_type == "ref_spider" then
        local refer = get_method_and_params()['params']['refer']
        back_url = back_url .. '?verify=pass&spider_type=' .. spider_type .. '&refer=' .. refer .. '";'
    -- uuid
    elseif spider_type == "url_spider" then
        local uuid = get_method_and_params()['params']['uuid']
        back_url = back_url .. '?verify=pass&spider_type=' .. spider_type .. '&uuid=' .. uuid .. '";'
    else
    end
end


html = [[
<!DOCTYPE html>
<html>
<head lang="en">
    <meta charset="UTF-8">
    <title>验证码</title>
</head>

<style>
    body {
        background-color: #f3f1ec;
    }
    .aa {
        width:0;
        height:0;
        position:fixed;
        left:50%;
        rigth:50%;
        top:50%;
        bottom:50%;
    }
    .aaa {
        background-color:#fff;
        font-size:18px;
        font-family:"Comic Sans MS", cursive;
        text-align:center;
        line-height:220px;
        width:600px;
        height:220px;
        margin-left:-300px;
        margin-top:-200px;
    }
</style>

<body>
<div class="aa">
    <div style="width:200px;margin-left:-270px;margin-top:-200px;position:fixed"><h4>尊敬的用户：</h4></div>
    <div style="width:200px;margin-left:-250px;margin-top:-150px;position:fixed"><h7 style="color:#red">您的访问过于频繁：</h7></div>
    <div class="aaa">
        <font style="color:red">请输入验证码：</font>
        <input type="text" id="code1"/>
        <div id="vCode1" style="line-height:19px; top:5px; width:100px; height: 30px; border: 1px solid #ccc; display: inline-block;"></div>
        <button id="btn1" style="font-size:14px; background:#3385ff;color: white;letter-spacing: 1px;border: 1px solid #2d78f4;outline: medium;-webkit-appearance: none;-webkit-border-radius: 0;position:relative; top:80px;left:55px;line-height:20px;">验证</button>
    </div>
</div>
</body>

<script>
    (function(){
    var randstr = function(length){
        var key = {
 
            str : [
                'a','b','c','d','e','f','g','h','i','j','k','l','m',
                'o','p','q','r','s','t','x','u','v','y','z','w','n',
                '0','1','2','3','4','5','6','7','8','9'
            ],
 
            randint : function(n,m){
                var c = m-n+1;
                var num = Math.random() * c + n;
                return  Math.floor(num);
            },
 
            randStr : function(){
                var _this = this;
                var leng = _this.str.length - 1;
                var randkey = _this.randint(0, leng);
                return _this.str[randkey];
            },
 
            create : function(len){
                var _this = this;
                var l = len || 10;
                var str = '';
 
                for(var i = 0 ; i<l ; i++){
                    str += _this.randStr();
                }
 
                return str;
            }
 
        };
 
        length = length ? length : 10;
 
        return key.create(length);
    };
 
    var randint = function(n,m){
        var c = m-n+1;
        var num = Math.random() * c + n;
        return  Math.floor(num);
    };
 
    var vCode = function(dom, options){
        this.codeDoms = [];
        this.lineDoms = [];
        this.initOptions(options);
        this.dom = dom;
        this.init();
        this.addEvent();
        this.update();
        this.mask();
    };
 
    vCode.prototype.init = function(){
        this.dom.style.position = "relative";
        this.dom.style.overflow = "hidden";
        this.dom.style.cursor = "pointer";
        this.dom.title = "点击更换验证码";
        this.dom.style.background = this.options.bgColor;
        this.w = this.dom.clientWidth;
        this.h = this.dom.clientHeight;
        this.uW = this.w / this.options.len;
    };
 
    vCode.prototype.mask = function(){
        var dom = document.createElement("div");
        dom.style.cssText = [
            "width: 100%",
            "height: 100%",
            "left: 0",
            "top: 0",
            "position: absolute",
            "cursor: pointer",
            "z-index: 9999999"
        ].join(";");
 
        dom.title = "点击更换验证码";
 
        this.dom.appendChild(dom);
    };
 
    vCode.prototype.addEvent = function(){
        var _this = this;
        _this.dom.addEventListener("click", function(){
            _this.update.call(_this);
        });
    };
 
    vCode.prototype.initOptions = function(options){
 
        var f = function(){
            this.len = 4;
            this.fontSizeMin = 20;
            this.fontSizeMax = 48;
            this.colors = [
                "green",
                "red",
                "blue",
                "#53da33",
                "#AA0000",
                "#FFBB00"
            ];
            this.bgColor = "#FFF";
            this.fonts = [
                "Times New Roman",
                "Georgia",
                "Serif",
                "sans-serif",
                "arial",
                "tahoma",
                "Hiragino Sans GB"
            ];
            this.lines = 8;
            this.lineColors = [
                "#888888",
                "#FF7744",
                "#888800",
                "#008888"
            ];
 
            this.lineHeightMin = 1;
            this.lineHeightMax = 3;
            this.lineWidthMin = 1;
            this.lineWidthMax = 60;
        };
 
        this.options = new f();
 
        if(typeof options === "object"){
            for(i in options){
                this.options[i] = options[i];
            }
        }
    };
 
    vCode.prototype.update = function(){
        for(var i=0; i<this.codeDoms.length; i++){
            this.dom.removeChild(this.codeDoms[i]);
        }
        for(var i=0; i<this.lineDoms.length; i++){
            this.dom.removeChild(this.lineDoms[i]);
        }
        this.createCode();
        this.draw();
    };
 
    vCode.prototype.createCode = function(){
        this.code = randstr(this.options.len);
    };
 
    vCode.prototype.verify = function(code){
        return this.code === code;
    };
 
    vCode.prototype.draw = function(){
        this.codeDoms = [];
        for(var i=0; i<this.code.length; i++){
            this.codeDoms.push(this.drawCode(this.code[i], i));
        }
 
        // this.drawLines();
    };
 
    vCode.prototype.drawCode = function(code, index){
        var dom = document.createElement("span");
 
        dom.style.cssText = [
            "font-size:" + "30px",
            "color:" + this.options.colors[randint(0,  this.options.colors.length - 1)],
            "position: absolute",
            "left:" + randint(this.uW * index, this.uW * index + this.uW - 10) + "px",
            "top:"  + "4px",
            "font-family:" + "sans-serif",
            "font-weight:" + 500
        ].join(";");
 
        dom.innerHTML = code;
        this.dom.appendChild(dom);
 
        return dom;
    };
 
    this.vCode = vCode;
 
}).call(this);
</script>
<script>
    onload = function () {
        var container1 = document.getElementById("vCode1");
        var code1 = new vCode(container1);
        document.getElementById("btn1").addEventListener("click", function () {
            if(code1.verify(document.getElementById("code1").value)) {
                alert("验证通过！")
                window.location = ]].. back_url .. [[
            } else {
                alert("验证失败！")
            }
        }, false);
        
    };
</script>

</html>
]]
function say_html()
	ngx_log("warn", "输出验证码页面")
    -- ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say(html)
    -- return ngx.exit(ngx.status)
end

say_html()