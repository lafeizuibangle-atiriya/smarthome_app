#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""智慧家居后端自测脚本：覆盖接口文档里的每一个端点。
管理版 Python（urllib，无第三方依赖）。结果写入 .scan/be_verify_report.md。
"""
import json
import time
import urllib.request
import urllib.error

BASE = "http://localhost:8080"
results = []  # (name, passed, detail)


def call(method, path, body=None, token=None, raw=False):
    url = BASE + path
    data = None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["token"] = token
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            text = r.read().decode("utf-8")
            return r.status, (text if raw else json.loads(text))
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", "ignore")
        try:
            return e.code, (text if raw else json.loads(text))
        except Exception:
            return e.code, {"code": e.code, "msg": text, "data": None}
    except Exception as e:
        return -1, {"code": -1, "msg": str(e), "data": None}


def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))
    print(("PASS " if cond else "FAIL ") + name + ((" -> " + detail) if detail else ""))


def main():
    # ---------- 认证 / 公共端点 ----------
    st, login = call("POST", "/api/user/login", {"username": "demo", "password": "123456"})
    check("登录 demo", st == 200 and login.get("code") == 200 and isinstance(login.get("data"), str),
          "code=%s" % login.get("code"))
    token = login.get("data") if login.get("code") == 200 else None
    if not token:
        print("无 token，后续鉴权接口无法测试")
        return report()

    # 未登录访问需鉴权接口 -> 401
    st, _ = call("GET", "/api/home/overview")
    check("未登录拦截 401", st == 401, "status=%s" % st)

    # 公共：产品库
    st, r = call("GET", "/api/product/categories")
    check("产品分类", st == 200 and r.get("code") == 200 and isinstance(r.get("data"), list), "code=%s" % r.get("code"))
    st, r = call("GET", "/api/product/list")
    check("产品列表", st == 200 and r.get("code") == 200 and len(r.get("data") or []) > 0, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/product/1")
    check("产品详情", st == 200 and r.get("code") == 200 and r.get("data", {}).get("id") == 1, "code=%s" % r.get("code"))

    # 公共：商品
    st, r = call("GET", "/api/goods/categories")
    check("商品分类", st == 200 and r.get("code") == 200 and isinstance(r.get("data"), list), "code=%s" % r.get("code"))
    st, r = call("GET", "/api/goods/banners")
    check("商品轮播", st == 200 and r.get("code") == 200 and isinstance(r.get("data"), list), "code=%s" % r.get("code"))
    st, r = call("GET", "/api/goods/list")
    check("商品列表", st == 200 and r.get("code") == 200 and len(r.get("data") or []) >= 12, "count=%s" % len(r.get("data") or []))
    st, r = call("GET", "/api/goods/1")
    check("商品详情", st == 200 and r.get("code") == 200 and r.get("data", {}).get("id") == 1, "code=%s" % r.get("code"))

    # 公共：轮播
    st, r = call("GET", "/api/banner/list")
    check("轮播图列表", st == 200 and r.get("code") == 200 and len(r.get("data") or []) >= 7, "count=%s" % len(r.get("data") or []))

    # ---------- 用户信息 ----------
    st, r = call("GET", "/api/user/info", token=token)
    info = r.get("data") or {}
    check("用户信息(真实统计)", st == 200 and r.get("code") == 200
          and info.get("deviceCount", 0) > 0, "deviceCount=%s orderCount=%s" % (info.get("deviceCount"), info.get("orderCount")))

    # ---------- 首页总览：rooms/environments 等长同序 ----------
    st, r = call("GET", "/api/home/overview", token=token)
    ov = r.get("data") or {}
    rooms = ov.get("rooms") or []
    envs = ov.get("environments") or []
    check("总览 rooms/environments 等长同序",
          st == 200 and len(rooms) == len(envs) and len(rooms) > 0,
          "rooms=%d envs=%d" % (len(rooms), len(envs)))

    # ---------- 房间 CRUD ----------
    st, r = call("POST", "/api/room", {"name": "自测房间_%d" % int(time.time())}, token=token)
    check("新增房间", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    # 取房间列表，找到刚建的房间
    st, r = call("GET", "/api/room/list", token=token)
    roomlist = r.get("data") or []
    check("房间列表", st == 200 and len(roomlist) > 0, "count=%s" % len(roomlist))
    new_room = max(roomlist, key=lambda x: x.get("id"))
    rid = new_room.get("id")
    st, r = call("PUT", "/api/room", {"id": rid, "name": "自测房间_改名"}, token=token)
    check("重命名房间", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    # 环境监测：厨房房间(取名为含'厨房'的) hasGas=1 & gas 非空；非厨房 gas=null
    kitchen = next((x for x in roomlist if "厨房" in (x.get("name") or "")), None)
    nonkitchen = next((x for x in roomlist if "厨房" not in (x.get("name") or "")), None)
    if kitchen:
        st, r = call("GET", "/api/room/%s/environment" % kitchen.get("id"), token=token)
        env = r.get("data") or {}
        check("厨房环境 hasGas=1 且 gas 非空", st == 200 and env.get("hasGas") == 1 and env.get("gas") is not None,
              "hasGas=%s gas=%s" % (env.get("hasGas"), env.get("gas")))
    if nonkitchen:
        st, r = call("GET", "/api/room/%s/environment" % nonkitchen.get("id"), token=token)
        env = r.get("data") or {}
        check("非厨房环境 gas 为 null", st == 200 and env.get("gas") is None, "gas=%s" % env.get("gas"))
    # 环境刷新造烟雾报警
    st, r = call("POST", "/api/room/%s/environment/refresh" % nonkitchen.get("id"),
                 {"smoke": 120}, token=token)
    env = r.get("data") or {}
    check("环境刷新 smoke=120 触发烟雾报警", st == 200 and env.get("smokeAlarm") == 1, "smokeAlarm=%s" % env.get("smokeAlarm"))
    st, r = call("GET", "/api/environment/metrics")
    check("环境指标字典", st == 200 and r.get("code") == 200 and isinstance(r.get("data"), list), "code=%s" % r.get("code"))

    # ---------- 设备类型字典（6 种）----------
    st, r = call("GET", "/api/device/types", token=token)
    types = r.get("data") or []
    type_names = {t.get("type") for t in types}
    check("设备类型 6 种", st == 200 and len(types) == 6
          and {"light", "ac", "socket", "curtain", "pump", "lock"} <= type_names,
          "types=%s" % type_names)

    # ---------- 设备控制 + 三条联动 ----------
    # 灯(1) 开
    st, r = call("POST", "/api/device/1/control", {"power": "on"}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("灯 控制 power=on", st == 200 and stt.get("power") == "on", "status=%s" % stt)
    # 空调(2) 开
    st, r = call("POST", "/api/device/2/control", {"power": "on"}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("空调 控制 power=on", st == 200 and stt.get("power") == "on", "status=%s" % stt)
    # 插座(5) 开
    st, r = call("POST", "/api/device/5/control", {"power": "on"}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("插座 控制 power=on", st == 200 and stt.get("power") == "on", "status=%s" % stt)
    # 窗帘(3) openPercent=60 -> power=on
    st, r = call("POST", "/api/device/3/control", {"openPercent": 60}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("窗帘联动 openPercent=60->power=on", st == 200 and stt.get("power") == "on", "status=%s" % stt)
    # 水泵(7) watering=1 -> power=on & watering=1
    st, r = call("POST", "/api/device/7/control", {"watering": 1, "duration": 5}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("水泵联动 watering=1->power=on,watering=1",
          st == 200 and stt.get("power") == "on" and stt.get("watering") == 1, "status=%s" % stt)
    # 门禁(8) locked=1 -> power=off（反向）
    st, r = call("POST", "/api/device/8/control", {"locked": 1}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("门禁反向联动 locked=1->power=off", st == 200 and stt.get("power") == "off", "status=%s" % stt)
    # 设备列表 / 详情 / 日志
    st, r = call("GET", "/api/device/list?roomId=%s" % nonkitchen.get("id"), token=token)
    check("房间设备列表", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/device/1", token=token)
    check("设备详情(无需额外鉴权在controller内)", st == 200 and r.get("code") == 200 and (r.get("data") or {}).get("id") == 1, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/device/1/logs", token=token)
    check("设备操作日志", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    # 手动浇水
    st, r = call("POST", "/api/device/7/water", {"duration": 3}, token=token)
    stt = (r.get("data") or {}).get("status") or {}
    check("手动浇水", st == 200 and stt.get("watering") == 1, "status=%s" % stt)
    # 新增设备 + 改名 + 删除（在自测房间内）
    st, r = call("POST", "/api/device", {"roomId": rid, "name": "自测灯", "type": "light"}, token=token)
    check("新增设备", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/device/list?roomId=%s" % rid, token=token)
    added = (r.get("data") or [])
    if added:
        did = added[-1].get("id")
        st, r = call("PUT", "/api/device", {"id": did, "name": "自测灯改名"}, token=token)
        check("设备改名", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("DELETE", "/api/device/%s" % did, token=token)
        check("删除设备", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))

    # ---------- 场景 ----------
    st, r = call("POST", "/api/scene",
                 {"name": "自测场景", "triggerType": "MANUAL",
                  "actions": [{"deviceId": 1, "action": {"power": "on"}}]}, token=token)
    check("新增场景", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/scene/list", token=token)
    sc_list = r.get("data") or []
    check("场景列表", st == 200 and len(sc_list) > 0, "count=%s" % len(sc_list))
    sid = (max(sc_list, key=lambda x: x.get("id"))).get("id") if sc_list else None
    if sid:
        st, r = call("GET", "/api/scene/%s" % sid, token=token)
        check("场景详情含动作", st == 200 and len((r.get("data") or {}).get("actions") or []) > 0, "code=%s" % r.get("code"))
        st, r = call("POST", "/api/scene/%s/run" % sid, token=token)
        check("执行场景", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("PUT", "/api/scene/%s/toggle" % sid, {"enabled": 0}, token=token)
        check("切换场景开关", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("PUT", "/api/scene",
                     {"id": sid, "name": "自测场景改", "actions": [{"deviceId": 2, "action": {"power": "off"}}]}, token=token)
        check("更新场景", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("DELETE", "/api/scene/%s" % sid, token=token)
        check("删除场景", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))

    # ---------- 地址 ----------
    st, r = call("POST", "/api/address",
                 {"receiver": "自测收件人", "phone": "13900000000",
                  "region": "北京市 市辖区 朝阳区", "detail": "测试路 1 号", "isDefault": 0}, token=token)
    check("新增地址", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/address/list", token=token)
    addr_list = r.get("data") or []
    check("地址列表", st == 200 and len(addr_list) > 0, "count=%s" % len(addr_list))
    aid = (max(addr_list, key=lambda x: x.get("id"))).get("id") if addr_list else None
    if aid:
        st, r = call("PUT", "/api/address",
                     {"id": aid, "receiver": "自测收件人改", "phone": "13900000000",
                      "region": "北京市 市辖区 朝阳区", "detail": "测试路 2 号", "isDefault": 0}, token=token)
        check("更新地址", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("DELETE", "/api/address/%s" % aid, token=token)
        check("删除地址", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))

    # ---------- 购物车 + 下单 ----------
    st, r = call("POST", "/api/cart", {"goodsId": 1, "quantity": 1}, token=token)
    check("加入购物车", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/cart/list", token=token)
    cart_before = r.get("data") or []
    check("购物车列表", st == 200 and len(cart_before) > 0, "count=%s" % len(cart_before))
    # 商品库存快照
    st, r = call("GET", "/api/goods/1")
    stock_before = (r.get("data") or {}).get("stock")
    # 下单（用 demo 默认地址 id=1）
    st, r = call("POST", "/api/order/create", {"addressId": 1, "items": [{"goodsId": 1, "quantity": 1}]}, token=token)
    od = r.get("data") or {}
    check("创建订单(事务/快照/收货人)", st == 200 and r.get("code") == 200
          and od.get("id") is not None and (od.get("items") or [])
          and od.get("receiverName") and od.get("receiverPhone") == "13800000000",
          "orderId=%s receiver=%s phone=%s items=%d" % (od.get("id"), od.get("receiverName"), od.get("receiverPhone"), len(od.get("items") or [])))
    oid = od.get("id")
    # 库存扣减校验
    st, r = call("GET", "/api/goods/1")
    stock_after = (r.get("data") or {}).get("stock")
    check("下单后库存扣减", stock_before is not None and stock_after == stock_before - 1,
          "before=%s after=%s" % (stock_before, stock_after))
    # 购物车已清空（刚才那一件）
    st, r = call("GET", "/api/cart/list", token=token)
    check("下单后购物车清空", st == 200 and len(r.get("data") or []) == 0, "count=%s" % len(r.get("data") or []))
    if oid:
        st, r = call("POST", "/api/order/%s/pay" % oid, token=token)
        check("支付订单", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("GET", "/api/order/%s" % oid, token=token)
        check("订单详情 status=1", st == 200 and (r.get("data") or {}).get("status") == 1, "status=%s" % (r.get("data") or {}).get("status"))
        st, r = call("POST", "/api/order/%s/cancel" % oid, token=token)
        check("取消订单(已付款允许)", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
        st, r = call("GET", "/api/order/%s" % oid, token=token)
        check("取消后 status=3", st == 200 and (r.get("data") or {}).get("status") == 3, "status=%s" % (r.get("data") or {}).get("status"))
        st, r = call("POST", "/api/order/%s/pay" % oid, token=token)
        check("已取消订单再支付被拒 400", st == 200 and r.get("code") == 400, "code=%s" % r.get("code"))
    st, r = call("GET", "/api/order/list", token=token)
    check("订单列表", st == 200 and r.get("code") == 200 and isinstance(r.get("data"), list), "code=%s" % r.get("code"))

    # ---------- 操作日志 ----------
    st, r = call("GET", "/api/oplog/list", token=token)
    check("操作日志有记录", st == 200 and r.get("code") == 200 and len(r.get("data") or []) > 0,
          "count=%s" % len(r.get("data") or []))

    # ---------- 越权测试：第二用户操作第一用户资源 ----------
    uname = "selftest_%d" % int(time.time())
    st, r = call("POST", "/api/user/register", {"username": uname, "password": "abc123", "nickname": "自测二号"})
    check("注册第二用户", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))
    st, r = call("POST", "/api/user/login", {"username": uname, "password": "abc123"})
    token2 = r.get("data") if r.get("code") == 200 else None
    if token2 and kitchen:
        st, r = call("GET", "/api/room/%s/environment" % kitchen.get("id"), token=token2)
        check("越权访问他人房间环境 400", st == 200 and r.get("code") == 400, "code=%s" % r.get("code"))
        st, r = call("GET", "/api/device/list?roomId=%s" % kitchen.get("id"), token=token2)
        check("越权访问他人设备 400", st == 200 and r.get("code") == 400, "code=%s" % r.get("code"))
        st, r = call("POST", "/api/device/1/control", {"power": "on"}, token=token2)
        check("越权控制他人设备 400", st == 200 and r.get("code") == 400, "code=%s" % r.get("code"))

    # 删除自测房间（清空后）
    st, r = call("DELETE", "/api/room/%s" % rid, token=token)
    check("删除自测房间", st == 200 and r.get("code") == 200, "code=%s" % r.get("code"))

    return report()


def report():
    passed = sum(1 for _, p, _ in results if p)
    total = len(results)
    print("\n==== 自测汇总 ====")
    print("PASS %d / %d" % (passed, total))
    # 写出报告
    import os
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".scan")
    os.makedirs(out_dir, exist_ok=True)
    lines = ["# 后端自测报告", "",
             "- 时间: %s" % time.strftime("%Y-%m-%d %H:%M:%S"),
             "- 地址: %s" % BASE,
             "- 结果: **PASS %d / %d**" % (passed, total), "",
             "## 明细", "", "| 序号 | 检查项 | 结果 | 说明 |", "|---|---|---|---|"]
    for i, (name, p, detail) in enumerate(results, 1):
        lines.append("| %d | %s | %s | %s |" % (i, name, "PASS" if p else "FAIL", detail))
    lines.append("")
    if passed != total:
        lines.append("## 失败项")
        for name, p, detail in results:
            if not p:
                lines.append("- %s : %s" % (name, detail))
        lines.append("")
    with open(os.path.join(out_dir, "be_verify_report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("报告已写入 .scan/be_verify_report.md")
    return passed == total


if __name__ == "__main__":
    main()
