# -*- coding: utf-8 -*-
"""设备模块接口用例：总览 / 房间 / 设备增删改查 / 控制 / 日志分页。

覆盖维度：
- 正常：overview、类型字典、建房、建设备、控制、日志分页；
- 异常：控制不存在的设备、空指令、越界参数、只读字段下发、类型不合法；
- 边界：亮度 1/100/101、色温白名单、房间名 10/11 字符、pageSize 50。
"""
import pytest


# ==================== 正常 ====================

class TestOverview:
    def test_overview_success(self, api, room, device):
        """正常：首页总览返回房间、设备、模式等结构。"""
        data = api.ok("GET", "/api/home/overview")
        assert "rooms" in data and "mode" in data
        room_ids = [r["id"] for r in data["rooms"]]
        assert room in room_ids, "测试房间应出现在总览里"

    def test_device_types(self, api):
        """正常：设备类型字典返回 7 种（与 DeviceTypes.java 对应）。"""
        data = api.ok("GET", "/api/device/types")
        assert len(data) == 7
        names = {t.get("type") or t.get("key") or t.get("value") for t in data}
        assert "light" in names and "fan" in names


class TestRoom:
    def test_room_list(self, api, room):
        """正常：房间列表包含刚建的测试房间。"""
        rooms = api.ok("GET", "/api/room/list")
        assert room in [r["id"] for r in rooms]

    def test_room_add_and_delete(self, api):
        """正常：建房 -> 改名 -> 删除，全链路成功。"""
        name = "临时房间" + __import__("conftest").unique_suffix(4)
        api.ok("POST", "/api/room", json_body={"name": name})
        rooms = api.ok("GET", "/api/room/list")
        target = [r for r in rooms if r["name"] == name]
        assert target, "建房后应能查到"
        rid = target[0]["id"]
        api.ok("PUT", "/api/room", json_body={"id": rid, "name": "临时房间改"})
        api.ok("DELETE", f"/api/room/{rid}")


class TestDeviceCrud:
    def test_add_device_success(self, api, room):
        """正常：添加设备成功并出现在列表。"""
        name = "测试插座" + __import__("conftest").unique_suffix(4)
        api.ok("POST", "/api/device", json_body={"roomId": room, "name": name, "type": "fan"})
        devices = api.ok("GET", "/api/device/list", params={"roomId": room})
        assert name in [d["name"] for d in devices]

    def test_device_detail(self, api, device):
        """正常：设备详情返回名称与状态 JSON。"""
        data = api.ok("GET", f"/api/device/{device}")
        assert data["id"] == device

    def test_rename_device(self, api, device):
        """正常：重命名设备。"""
        api.ok("PUT", "/api/device", json_body={"id": device, "name": "测试灯改名"})

    def test_delete_device(self, api, room):
        """正常：添加后删除一台设备。"""
        name = "待删设备" + __import__("conftest").unique_suffix(4)
        api.ok("POST", "/api/device", json_body={"roomId": room, "name": name, "type": "light"})
        devices = api.ok("GET", "/api/device/list", params={"roomId": room})
        did = [d for d in devices if d["name"] == name][0]["id"]
        api.ok("DELETE", f"/api/device/{did}")
        devices = api.ok("GET", "/api/device/list", params={"roomId": room})
        assert did not in [d["id"] for d in devices]


class TestControl:
    def test_control_power_on(self, api, device):
        """正常：开灯，返回状态 power=on。"""
        data = api.ok("POST", f"/api/device/{device}/control", json_body={"power": "on"})
        assert data["status"]["power"] == "on"

    def test_control_power_off(self, api, device):
        """正常：关灯。"""
        data = api.ok("POST", f"/api/device/{device}/control", json_body={"power": "off"})
        assert data["status"]["power"] == "off"

    def test_control_brightness(self, api, device):
        """正常：设置合法亮度 80。"""
        data = api.ok("POST", f"/api/device/{device}/control", json_body={"brightness": 80})
        assert data["status"]["brightness"] == 80


# ==================== 异常 ====================

class TestControlError:
    def test_control_device_not_exist(self, api):
        """异常：控制不存在的设备。"""
        api.biz_fail("POST", "/api/device/999999/control",
                     expect_msg="设备不存在", json_body={"power": "on"})

    def test_control_empty_action(self, api, device):
        """异常：控制指令为空 body。"""
        api.biz_fail("POST", f"/api/device/{device}/control",
                     expect_msg="指令不能为空", json_body={})

    def test_control_brightness_over_max(self, api, device):
        """异常：亮度 101 越界（后端校验 1~100）。"""
        api.biz_fail("POST", f"/api/device/{device}/control",
                     expect_msg="brightness", json_body={"brightness": 101})

    def test_control_brightness_zero(self, api, device):
        """异常：亮度 0 越界。"""
        api.biz_fail("POST", f"/api/device/{device}/control",
                     expect_msg="brightness", json_body={"brightness": 0})

    def test_control_colortemp_invalid(self, api, device):
        """异常：色温 3000 不在白名单（2700/4000/6500）。"""
        api.biz_fail("POST", f"/api/device/{device}/control",
                     expect_msg="色温", json_body={"colorTemp": 3000})

    def test_control_readonly_field(self, api, device):
        """异常：下发只读字段 smoke（防伪造传感器数据），无可执行项被拒。"""
        api.biz_fail("POST", f"/api/device/{device}/control",
                     expect_msg="没有可执行", json_body={"smoke": 999})

    def test_add_device_bad_type(self, api, room):
        """异常：设备类型不在字典中。"""
        api.biz_fail("POST", "/api/device",
                     expect_msg="不支持的设备类型",
                     json_body={"roomId": room, "name": "假设备", "type": "hacker_device"})

    def test_add_device_name_too_long(self, api, room):
        """异常：设备名 21 字符超过 @Size(max=20)。"""
        api.biz_fail("POST", "/api/device",
                     expect_msg="20",
                     json_body={"roomId": room, "name": "名" * 21, "type": "light"})

    def test_device_list_without_token(self, api, room):
        """异常：不带 token 查设备列表，HTTP 401。"""
        api.unauthorized("GET", "/api/device/list", params={"roomId": room})


# ==================== 日志分页（2026-11-23 新接口） ====================

class TestLogsPage:
    def test_logs_page_default(self, api, device):
        """正常：默认参数（pageNum=1, pageSize=10）返回 PageVO 结构。"""
        data = api.ok("GET", f"/api/device/{device}/logs/page")
        assert set(data.keys()) >= {"list", "total", "pageNum", "pageSize"}
        assert len(data["list"]) <= 10
        assert data["total"] >= 0

    def test_logs_page_small_size(self, api, device):
        """正常：pageSize=5，页内条数不超过 5。"""
        data = api.ok("GET", f"/api/device/{device}/logs/page",
                      params={"pageNum": 1, "pageSize": 5})
        assert len(data["list"]) <= 5 and data["pageSize"] == 5

    def test_logs_page_boundary_50(self, api, device):
        """边界：pageSize=50（上限）可用。"""
        data = api.ok("GET", f"/api/device/{device}/logs/page",
                      params={"pageNum": 1, "pageSize": 50})
        assert len(data["list"]) <= 50

    def test_logs_page_empty(self, api, room):
        """边界：无日志的新设备返回空列表 total=0。"""
        name = "无日志设备" + __import__("conftest").unique_suffix(4)
        api.ok("POST", "/api/device", json_body={"roomId": room, "name": name, "type": "beep"})
        devices = api.ok("GET", "/api/device/list", params={"roomId": room})
        did = [d for d in devices if d["name"] == name][0]["id"]
        data = api.ok("GET", f"/api/device/{did}/logs/page")
        assert data["list"] == [] and data["total"] == 0

    def test_logs_page_huge_page_num(self, api, device):
        """边界：pageNum 很大（超出数据页数）返回空列表不报错。"""
        data = api.ok("GET", f"/api/device/{device}/logs/page",
                      params={"pageNum": 9999, "pageSize": 10})
        assert data["list"] == []


# ==================== 边界 ====================

class TestRoomBoundary:
    def test_room_name_len_10(self, api):
        """边界：房间名 10 字符（@Size(max=10) 上限）成功。"""
        name = "十" * 10 + __import__("conftest").unique_suffix(0)
        api.ok("POST", "/api/room", json_body={"name": name})
        rooms = api.ok("GET", "/api/room/list")
        rid = [r for r in rooms if r["name"] == name][0]["id"]
        api.ok("DELETE", f"/api/room/{rid}")

    def test_room_name_len_11(self, api):
        """边界：房间名 11 字符超限被拒。"""
        api.biz_fail("POST", "/api/room", expect_msg="10", json_body={"name": "十" * 11})
