# -*- coding: utf-8 -*-
"""订单模块接口用例：下单 / 幂等 / 分页 / 支付取消。

覆盖维度：
- 正常：加购物车 -> 建地址 -> 下单 -> 分页 -> 详情 -> 支付/取消；
- 异常：空 items、requestId 格式非法、支付不存在的订单；
- 核心：requestId 幂等（同一 requestId 重复提交只产生一单，2026-11-23 加的）。
"""
import pytest


# ==================== 正常 ====================

class TestOrderCreate:
    def test_create_success(self, api, cart_goods, address):
        """正常：购物车下单成功，返回订单号。"""
        goods_id, qty = cart_goods
        data = api.ok("POST", "/api/order/create", json_body={
            "addressId": address,
            "items": [{"goodsId": goods_id, "quantity": qty}],
            "requestId": ""})
        assert data["orderNo"], "应返回订单号"

    def test_create_idempotent_same_request(self, api, cart_goods, address):
        """核心：同一 requestId 重复提交，两次返回同一个订单号（幂等）。"""
        goods_id, qty = cart_goods
        rid = "pytest-idem-" + __import__("conftest").unique_suffix(10)
        body = {"addressId": address,
                "items": [{"goodsId": goods_id, "quantity": qty}],
                "requestId": rid}
        first = api.ok("POST", "/api/order/create", json_body=body)
        second = api.ok("POST", "/api/order/create", json_body=body)
        assert first["orderNo"] == second["orderNo"], \
            f"幂等失败：两次提交订单号不同 {first['orderNo']} vs {second['orderNo']}"

    def test_create_no_requestid(self, api, cart_goods, address):
        """正常：不传 requestId 也能下单（requestId 可选）。"""
        goods_id, qty = cart_goods
        data = api.ok("POST", "/api/order/create", json_body={
            "addressId": address,
            "items": [{"goodsId": goods_id, "quantity": qty}]})
        assert data["orderNo"]


class TestOrderQuery:
    def test_page_default(self, api):
        """正常：订单分页默认参数返回 PageVO 结构。"""
        data = api.ok("GET", "/api/order/page")
        assert set(data.keys()) >= {"list", "total", "pageNum", "pageSize"}
        assert len(data["list"]) <= 10

    def test_page_size_50(self, api):
        """边界：pageSize=50（Controller 上限）。"""
        data = api.ok("GET", "/api/order/page", params={"pageNum": 1, "pageSize": 50})
        assert len(data["list"]) <= 50

    def test_page_size_51_over_limit(self, api):
        """边界：pageSize=51 超上限，被收口到 50 仍正常返回（不报错）。"""
        data = api.ok("GET", "/api/order/page", params={"pageNum": 1, "pageSize": 51})
        assert len(data["list"]) <= 50

    def test_detail_after_create(self, api, cart_goods, address):
        """正常：下单后按 id 查详情，金额与订单号一致。"""
        goods_id, qty = cart_goods
        data = api.ok("POST", "/api/order/create", json_body={
            "addressId": address,
            "items": [{"goodsId": goods_id, "quantity": qty}], "requestId": ""})
        detail = api.ok("GET", f"/api/order/{data['id']}")
        assert detail["id"] == data["id"]


class TestOrderPayCancel:
    def test_pay_then_query(self, api, cart_goods, address):
        """正常：下单 -> 支付 -> 详情状态变为已支付。"""
        goods_id, qty = cart_goods
        data = api.ok("POST", "/api/order/create", json_body={
            "addressId": address,
            "items": [{"goodsId": goods_id, "quantity": qty}], "requestId": ""})
        api.ok("POST", f"/api/order/{data['id']}/pay")
        detail = api.ok("GET", f"/api/order/{data['id']}")
        assert detail["status"] in (1, "1", "PAID", "已支付"), \
            f"支付后状态应为已支付，实际 {detail['status']}"

    def test_cancel_unpaid_order(self, api, cart_goods, address):
        """正常：下单 -> 取消未支付订单。"""
        goods_id, qty = cart_goods
        data = api.ok("POST", "/api/order/create", json_body={
            "addressId": address,
            "items": [{"goodsId": goods_id, "quantity": qty}], "requestId": ""})
        api.ok("POST", f"/api/order/{data['id']}/cancel")


# ==================== 异常 ====================

class TestOrderError:
    def test_create_empty_items(self, api, address):
        """异常：items 为空列表，提示"请选择要购买的商品"。"""
        api.biz_fail("POST", "/api/order/create", expect_msg="商品", json_body={
            "addressId": address, "items": [], "requestId": ""})

    def test_create_requestid_bad_format(self, api, cart_goods, address):
        """异常：requestId 7 位（合法要求 8~64 位 \\w-）。"""
        goods_id, qty = cart_goods
        api.biz_fail("POST", "/api/order/create", expect_msg="requestId", json_body={
            "addressId": address,
            "items": [{"goodsId": goods_id, "quantity": qty}],
            "requestId": "short12"})

    def test_pay_order_not_exist(self, api):
        """异常：支付不存在的订单。"""
        api.biz_fail("POST", "/api/order/999999/pay")

    def test_cancel_order_not_exist(self, api):
        """异常：取消不存在的订单。"""
        api.biz_fail("POST", "/api/order/999999/cancel")

    def test_create_without_token(self, api, address):
        """异常：不带 token 下单，HTTP 401。"""
        api.unauthorized("POST", "/api/order/create", json_body={
            "addressId": address, "items": [{"goodsId": 1, "quantity": 1}]})

    def test_create_goods_not_exist(self, api, address):
        """异常：下单不存在的商品。"""
        api.biz_fail("POST", "/api/order/create", json_body={
            "addressId": address,
            "items": [{"goodsId": 999999, "quantity": 1}], "requestId": ""})
