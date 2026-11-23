# -*- coding: utf-8 -*-
"""pytest 全局 fixture 与 HTTP 封装。

接口契约（《03_接口文档.md》 + GlobalExceptionHandler / LoginInterceptor）：
- 统一返回体 {code, msg, data}，code=200 成功 / 400 业务错或参数错 / 500 系统错；
- 业务错误与参数校验错误都是 HTTP 200 + body.code=400；
- 未登录由拦截器直接写回：HTTP 401 + {"code":401,"msg":"请先登录"}；
- 登录态通过请求头 token 传递（注意不是 Authorization）。
"""
import random
import string

import pytest
import requests

BASE_URL = "http://localhost:8080"
TIMEOUT = 15


def unique_suffix(n=8):
    """生成随机后缀，保证注册类用例可重复执行（库里不撞用户名）。"""
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


class Api:
    """requests 薄封装：自动带 token 头 + 断言助手。"""

    def __init__(self):
        self.session = requests.Session()
        self.token = None

    def _headers(self, extra=None):
        h = {}
        if self.token:
            h["token"] = self.token
        if extra:
            h.update(extra)
        return h

    def request(self, method, path, json_body=None, params=None, headers=None):
        resp = self.session.request(
            method, BASE_URL + path, json=json_body, params=params,
            headers=self._headers(headers), timeout=TIMEOUT)
        return resp

    def get(self, path, **kw):
        return self.request("GET", path, **kw)

    def post(self, path, json_body=None, **kw):
        return self.request("POST", path, json_body=json_body, **kw)

    def put(self, path, json_body=None, **kw):
        return self.request("PUT", path, json_body=json_body, **kw)

    def delete(self, path, **kw):
        return self.request("DELETE", path, **kw)

    # ---- 断言助手：把"业务成功/业务失败"的判断统一收口 ----

    def ok(self, method, path, **kw):
        """请求成功（HTTP 200 且 body.code == 200），返回 data。"""
        resp = self.request(method, path, **kw)
        assert resp.status_code == 200, f"[{method} {path}] HTTP {resp.status_code}: {resp.text[:200]}"
        body = resp.json()
        assert body["code"] == 200, f"[{method} {path}] 业务失败 code={body['code']} msg={body.get('msg')}"
        return body["data"]

    def biz_fail(self, method, path, expect_msg=None, **kw):
        """请求业务失败（HTTP 200 且 body.code == 400），返回 msg。"""
        resp = self.request(method, path, **kw)
        assert resp.status_code == 200, f"[{method} {path}] HTTP {resp.status_code}: {resp.text[:200]}"
        body = resp.json()
        assert body["code"] == 400, f"[{method} {path}] 预期业务失败，实际 code={body['code']} msg={body.get('msg')}"
        if expect_msg is not None:
            assert expect_msg in body["msg"], f"[{method} {path}] msg 应包含'{expect_msg}'，实际: {body['msg']}"
        return body["msg"]

    def unauthorized(self, method, path, **kw):
        """请求被拦截器拒绝（HTTP 401）。刻意走裸 requests，不带任何 token，
        因为 self.token 在 session 级 fixture 登录后已经挂上了。"""
        resp = requests.request(method, BASE_URL + path, timeout=TIMEOUT,
                                json=kw.get("json_body"), params=kw.get("params"),
                                headers=kw.get("headers"))
        assert resp.status_code == 401, \
            f"[{method} {path}] 预期 HTTP 401，实际 {resp.status_code}: {resp.text[:200]}"


@pytest.fixture(scope="session")
def api():
    """全局 HTTP 客户端（session 级，整轮测试共用）。"""
    return Api()


@pytest.fixture(scope="session")
def user(api):
    """注册一个独立测试账号并登录，返回 dict(username/password/token)。

    用随机用户名，重复跑不冲突，也不污染 demo 用户的数据。
    """
    username = "apitest_" + unique_suffix()
    password = "Pytest@123"
    r = api.post("/api/user/register", json_body={
        "username": username, "nickname": "接口测试", "password": password})
    assert r.json()["code"] == 200, "前置：注册测试账号失败 " + r.text

    data = api.ok("POST", "/api/user/login", json_body={
        "username": username, "password": password})
    assert isinstance(data, str) and len(data) > 20, "登录应返回 JWT 字符串"
    api.token = data
    return {"username": username, "password": password, "token": data}


@pytest.fixture(scope="session")
def room(api, user):
    """为测试账号建一个房间，返回房间 id。"""
    api.ok("POST", "/api/room", json_body={"name": "接口测试房"})
    rooms = api.ok("GET", "/api/room/list")
    target = [r for r in rooms if r["name"] == "接口测试房"]
    assert target, "前置：建房间后应在列表中找到"
    return target[0]["id"]


@pytest.fixture(scope="session")
def device(api, room):
    """在测试房间加一台灯，返回设备 id。"""
    api.ok("POST", "/api/device", json_body={"roomId": room, "name": "测试灯", "type": "light"})
    devices = api.ok("GET", "/api/device/list", params={"roomId": room})
    target = [d for d in devices if d["name"] == "测试灯"]
    assert target, "前置：添加设备后应在列表中找到"
    return target[0]["id"]


@pytest.fixture(scope="session")
def address(api, user):
    """为测试账号建一个收货地址，返回地址 id。"""
    api.ok("POST", "/api/address", json_body={
        "receiver": "接口测试", "phone": "13800001111",
        "region": "江西省 南昌市 青山湖区", "detail": "测试大道 1 号", "isDefault": 1})
    addresses = api.ok("GET", "/api/address/list")
    assert addresses, "前置：添加地址后应在列表中找到"
    return addresses[-1]["id"]


@pytest.fixture()
def cart_goods(api, user):
    """往购物车里加一件商品，返回 (goodsId, quantity)。用例结束后清理。"""
    goods_id = 1
    api.ok("POST", "/api/cart", json_body={"goodsId": goods_id, "quantity": 1})
    yield goods_id, 1
    # 清理：把这件购物车项删掉
    items = api.ok("GET", "/api/cart/list")
    for it in items:
        if it.get("goodsId") == goods_id:
            api.delete(f"/api/cart/{it['id']}")
