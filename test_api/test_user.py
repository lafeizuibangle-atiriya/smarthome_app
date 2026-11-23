# -*- coding: utf-8 -*-
"""用户模块接口用例：注册 / 登录 / 用户信息。

覆盖维度：
- 正常：注册、登录、获取当前用户信息；
- 异常：重复注册、密码错误、用户不存在、参数缺失、伪造 token；
- 边界：用户名长度 20/21、密码长度 6/5/32/33。
"""
import random
import string

import pytest

from conftest import unique_suffix


def make_username(length=20):
    """生成指定长度的合法用户名（a-z 开头避免纯数字）。"""
    return "u" + "".join(random.choices(string.ascii_lowercase, k=length - 1))


# ==================== 正常 ====================

class TestRegister:
    def test_register_success(self, api):
        """正常：注册新用户返回成功。"""
        username = "apitest_" + unique_suffix()
        data = api.ok("POST", "/api/user/register", json_body={
            "username": username, "nickname": "正常注册", "password": "Abc@123456"})
        assert data is None

    def test_register_duplicate(self, api, user):
        """异常：重复用户名注册被拒绝。"""
        api.biz_fail("POST", "/api/user/register", expect_msg="已被注册", json_body={
            "username": user["username"], "nickname": "重复注册", "password": "Abc@123456"})


class TestLogin:
    def test_login_success(self, api, user):
        """正常：正确账号密码登录，data 是 token 字符串。"""
        data = api.ok("POST", "/api/user/login", json_body={
            "username": user["username"], "password": user["password"]})
        assert isinstance(data, str) and len(data) > 20

    def test_login_wrong_password(self, api, user):
        """异常：密码错误登录失败。"""
        api.biz_fail("POST", "/api/user/login", expect_msg="密码", json_body={
            "username": user["username"], "password": "WrongPwd@123"})

    def test_login_user_not_exist(self, api):
        """异常：不存在的用户登录失败。"""
        api.biz_fail("POST", "/api/user/login", json_body={
            "username": "no_such_user_" + unique_suffix(), "password": "Abc@123456"})

    def test_login_blank_username(self, api):
        """异常：用户名为空触发参数校验（2026-11-23 加 @NotBlank）。"""
        api.biz_fail("POST", "/api/user/login", expect_msg="username", json_body={
            "username": "", "password": "Abc@123456"})

    def test_login_blank_password(self, api):
        """异常：密码为空触发参数校验。"""
        api.biz_fail("POST", "/api/user/login", expect_msg="password", json_body={
            "username": "somebody", "password": ""})

    def test_login_missing_body(self, api):
        """异常：不发请求体（JSON 解析失败）。"""
        resp = api.request("POST", "/api/user/login",
                           headers={"Content-Type": "application/json"})
        assert resp.status_code == 200
        body = resp.json()
        assert body["code"] == 400 and "请求体" in body["msg"]


class TestUserInfo:
    def test_info_success(self, api, user):
        """正常：登录后能拿到用户信息（含统计数）。"""
        data = api.ok("GET", "/api/user/info")
        assert data["username"] == user["username"]
        assert "deviceCount" in data and "orderCount" in data

    def test_info_without_token(self, api):
        """异常：不带 token 访问受保护接口，HTTP 401。"""
        api.unauthorized("GET", "/api/user/info")

    def test_info_with_fake_token(self, api):
        """异常：伪造 token 被 JWT 校验拒绝，HTTP 401。"""
        api.unauthorized("GET", "/api/user/info",
                         headers={"token": "fake.token.value"})


# ==================== 边界 ====================

class TestBoundary:
    def test_register_username_len_20(self, api):
        """边界：用户名 20 字符（上限）注册成功。"""
        api.ok("POST", "/api/user/register", json_body={
            "username": make_username(20), "nickname": "边界20", "password": "Abc@123456"})

    def test_register_username_len_21(self, api):
        """边界：用户名 21 字符（超上限）注册失败。"""
        api.biz_fail("POST", "/api/user/register", expect_msg="20", json_body={
            "username": make_username(21), "nickname": "边界21", "password": "Abc@123456"})

    def test_register_password_len_6(self, api):
        """边界：密码 6 位（下限）注册成功。"""
        api.ok("POST", "/api/user/register", json_body={
            "username": "apitest_" + unique_suffix(), "nickname": "边界6", "password": "abc123"})

    def test_register_password_len_5(self, api):
        """边界：密码 5 位（低于下限）注册失败。"""
        api.biz_fail("POST", "/api/user/register", expect_msg="6", json_body={
            "username": "apitest_" + unique_suffix(), "nickname": "边界5", "password": "abc12"})

    def test_register_password_len_32(self, api):
        """边界：密码 32 位（上限）注册成功。"""
        pwd = "a" * 32
        api.ok("POST", "/api/user/register", json_body={
            "username": "apitest_" + unique_suffix(), "nickname": "边界32", "password": pwd})

    def test_register_password_len_33(self, api):
        """边界：密码 33 位（超上限）注册失败。"""
        api.biz_fail("POST", "/api/user/register", expect_msg="32", json_body={
            "username": "apitest_" + unique_suffix(), "nickname": "边界33", "password": "a" * 33})
