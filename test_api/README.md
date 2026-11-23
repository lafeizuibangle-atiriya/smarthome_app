# 接口自动化测试（Pytest + requests）

对智慧家居后端（`smarthome_server`）的 REST 接口做自动化用例，覆盖正常 / 异常 / 边界三类。

## 运行前提

1. MySQL（3306）、Redis（6379）已启动；
2. 后端已启动在 `http://localhost:8080`；
3. Python 装了 `pytest`、`requests`、`pytest-html`。

## 运行

```bash
cd test_api
python -m pytest
```

报告自动生成到 `report/report.html`（自包含单文件，浏览器直接打开）。

只跑某一模块：

```bash
python -m pytest test_user.py
python -m pytest test_device.py -k "control"
```

## 目录结构

| 文件 | 内容 |
|---|---|
| `conftest.py` | HTTP 封装（自动带 token 头）、统一返回体断言助手、fixture：注册登录/建房/建设备/建地址/购物车 |
| `test_user.py` | 注册、登录、用户信息（14 条） |
| `test_device.py` | 首页总览、房间、设备增删改查、控制、日志分页（27 条） |
| `test_order.py` | 下单、幂等、分页、支付取消（18 条） |

## 用例设计要点

- **数据隔离**：session 级 fixture 随机注册一个 `apitest_xxx` 账号，所有用例在该账号名下建房/建设备/下单，不污染 demo 用户数据；临时房间/设备/购物车项用完即删。
- **断言收口**：`api.ok()` 断言 HTTP 200 + `code==200`；`api.biz_fail()` 断言业务错 `code==400` 且可校验提示语；`api.unauthorized()` 断言拦截器 HTTP 401。
- **幂等核心用例**：`test_create_idempotent_same_request` —— 同一 requestId 提交两次，断言返回同一个订单号。
- 可重复执行：所有注册类用例用随机用户名，跑多少次都不冲突。

## 已发现并修复的问题

- `RoomController.add` 原来接收 `Map`，`RoomDTO` 上的 `@Size(max=10)` 校验没生效（房间名 11 字符也能建）。已改为 `@Valid @RequestBody RoomDTO`，用例 `test_room_name_len_11` 验证修复。
