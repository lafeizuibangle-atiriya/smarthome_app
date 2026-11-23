import json, urllib.request, urllib.error
BASE="http://localhost:8080"
def call(method,path,body=None,token=None):
    h={"Content-Type":"application/json"}
    if token: h["token"]=token
    data=json.dumps(body).encode() if body is not None else None
    req=urllib.request.Request(BASE+path,data=data,method=method,headers=h)
    try:
        with urllib.request.urlopen(req,timeout=15) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8","ignore")
    except Exception as e:
        return -1, str(e)

# login
_,t=call("POST","/api/user/login",{"username":"demo","password":"123456"})
token=json.loads(t).get("data")
print("LOGIN", token[:12] if token else None)
for path,need_token in [("/api/home/overview",False),("/api/room/list",False),
                        ("/api/goods/categories",False),("/api/device/types",True),
                        ("/api/environment/metrics",True),("/api/oplog/list",True),
                        ("/api/device/1",True)]:
    st,body=call("GET",path,token=token if need_token else None)
    print("==",path,"token=",need_token,"status=",st)
    print("   ", body[:300])
