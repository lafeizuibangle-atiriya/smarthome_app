#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""智慧家居 App · 设备模拟器（HTTP 版）

=====================================================================
它是什么
=====================================================================
在没有真实硬件（BearPi 开发板还在路上）时，"冒充设备端"——
用和真板子完全相同的后端接口，把环境/传感器数据喂给 Spring Boot，
并模拟设备对 App 下发指令的执行动作。

=====================================================================
为什么走 HTTP 而不是 MQTT
=====================================================================
当前 smarthome_server 没有引入 MQTT，设备和 App 共用的就是那套 REST 接口
（/api/room/{roomId}/environment/refresh 等）。走 HTTP = 零新增基础设施。
真板子（HM Nano / IoT Std）联网后也调同一套接口，
所以"模拟器"和"真设备"对后端而言是同一种东西，可以无缝替换。

=====================================================================
数据映射（E53 扩展板 → 后端字段）
=====================================================================
    E53_IA1  温湿度        -> temperature / humidity
    E53_IA1  光照          -> aqi / co2（由光照和时段推导，纯演示，非真实值）
    E53_SF1  烟雾          -> smoke（超过后端阈值会自动置 smokeAlarm=1）
    E53_SF1  燃气          -> gas（仅 hasGas=1 的房间，通常是厨房）
    E53_IS1  人体红外      -> 后端没有"有人"字段，转成"回家自动开灯"：
                              检测到有人 -> 控制同房间的 light 设备开灯

=====================================================================
用法
=====================================================================
    python device_simulator.py                 常驻，按 config.ini 的间隔上报
    python device_simulator.py --once          只跑一轮（验证链路用）
    python device_simulator.py --dry-run       不请求后端，只打印将要发送的数据
    python device_simulator.py --config a.ini  指定配置文件
    python device_simulator.py --no-events     关闭随机事件（只想看平稳数据时）

依赖：requests（仅"真连后端"时需要；--dry-run 不需要）
"""

from __future__ import annotations

import argparse
import configparser
import json
import os
import random
import sys
import time
from datetime import datetime

# requests 只在真连后端时才需要，--dry-run 不装也能跑
try:
    import requests
except ImportError:  # pragma: no cover
    requests = None


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------
def now_str() -> str:
    return datetime.now().strftime("%H:%M:%S")


def log(tag: str, msg: str) -> None:
    """统一日志格式：[时分秒] [标签] 内容"""
    print(f"[{now_str()}] [{tag}] {msg}", flush=True)


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def random_walk(value: float, step: float, low: float, high: float) -> float:
    """随机游走：在当前值附近小幅波动，并卡在 [low, high] 内。
    比"每次纯随机"更真实——真实传感器的读数不会瞬间从 20℃ 跳到 30℃。"""
    return clamp(value + random.uniform(-step, step), low, high)


# ---------------------------------------------------------------------------
# 后端客户端
# ---------------------------------------------------------------------------
class BackendClient:
    """封装后端 REST 调用。登录一次拿 token，401 时自动重登。

    注意：鉴权请求头名字是 `token`（不是 Authorization），
         这是项目 LoginInterceptor 的约定，见 smarthome_server/config/LoginInterceptor.java。
    """

    def __init__(self, base_url: str, username: str, password: str, timeout: float = 5.0):
        self.base_url = base_url.rstrip("/")
        self.username = username
        self.password = password
        self.timeout = timeout
        self.token = None
        if requests is None:
            raise RuntimeError("缺少 requests 库，请先执行： pip install -r requirements.txt")
        self.session = requests.Session()

    # ---- 基础 ----
    def _url(self, path: str) -> str:
        return self.base_url + path

    def login(self) -> None:
        resp = self.session.post(
            self._url("/api/user/login"),
            json={"username": self.username, "password": self.password},
            timeout=self.timeout,
        )
        body = resp.json()
        if body.get("code") != 200:
            raise RuntimeError(f"登录失败：code={body.get('code')} msg={body.get('msg')}")
        self.token = body.get("data")
        self.session.headers.update({"token": self.token})
        log("后端", f"登录成功（{self.username}）")

    def request(self, method: str, path: str, **kwargs):
        """带自动重登的请求。返回解析后的 JSON（{code, msg, data}）"""
        if self.token is None:
            self.login()
        resp = self.session.request(method, self._url(path), timeout=self.timeout, **kwargs)
        if resp.status_code == 401:                 # token 过期 -> 重登再试一次
            log("后端", "token 失效，重新登录")
            self.login()
            resp = self.session.request(method, self._url(path), timeout=self.timeout, **kwargs)
        try:
            return resp.json()
        except ValueError:
            raise RuntimeError(f"响应不是合法 JSON（HTTP {resp.status_code}）：{resp.text[:200]}")

    # ---- 业务接口 ----
    def rooms(self) -> list:
        return self.request("GET", "/api/room/list").get("data") or []

    def devices(self, room_id: int) -> list:
        return self.request("GET", f"/api/device/list?roomId={room_id}").get("data") or []

    def environment(self, room_id: int) -> dict:
        return self.request("GET", f"/api/room/{room_id}/environment").get("data") or {}

    def refresh_environment(self, room_id: int, payload: dict) -> dict:
        """上报环境数据。payload 里只放"本设备测到的量"，其余后端会自己抖一下。"""
        return self.request(
            "POST", f"/api/room/{room_id}/environment/refresh", json=payload
        ).get("data") or {}

    def control_device(self, device_id: int, action: dict) -> dict:
        return self.request(
            "POST", f"/api/device/{device_id}/control", json=action
        ).get("data") or {}


# ---------------------------------------------------------------------------
# 单房间的"传感器"状态（模拟 E53_IA1）
# ---------------------------------------------------------------------------
class RoomSensor:
    """一个房间 = 一套 IA1 传感器。数值在合理区间内随机游走。"""

    def __init__(self, room_id: int, name: str, has_gas: bool = False):
        self.room_id = room_id
        self.name = name
        self.has_gas = has_gas
        self.temperature = random.uniform(22.0, 27.0)
        self.humidity = random.uniform(45.0, 60.0)
        self.lux = random.uniform(150.0, 600.0)      # 光照强度，用来推导 aqi / co2
        self.aqi = random.uniform(30.0, 80.0)
        self.co2 = random.uniform(450.0, 900.0)
        # 事件状态：还剩几轮处于"异常"，便于造出持续几秒的报警
        self.smoke_alert_cycles = 0
        self.gas_alert_cycles = 0

    def sample(self) -> dict:
        """采样一轮，返回要 POST 的 RoomEnvDTO 字段。"""
        self.temperature = random_walk(self.temperature, 0.35, 16.0, 32.0)
        self.humidity = random_walk(self.humidity, 1.5, 25.0, 85.0)
        self.lux = random_walk(self.lux, 40.0, 0.0, 1200.0)
        # 光照越强，通常越干燥/空气越好 —— 这里只是让 aqi、co2 有相关性，看着自然
        self.aqi = random_walk(self.aqi, 3.0, 10.0, 160.0)
        self.co2 = random_walk(self.co2, 25.0, 400.0, 1600.0)

        payload = {
            "temperature": round(self.temperature, 1),
            "humidity": int(self.humidity),
            "aqi": int(self.aqi),
            "co2": int(self.co2),
        }

        # 烟雾：平时低浓度，处于"报警轮次"时给高值（后端阈值 50）
        if self.smoke_alert_cycles > 0:
            self.smoke_alert_cycles -= 1
            payload["smoke"] = random.randint(55, 90)
        else:
            payload["smoke"] = random.randint(1, 6)

        # 燃气：只有支持燃气检测的房间才上报
        if self.has_gas:
            if self.gas_alert_cycles > 0:
                self.gas_alert_cycles -= 1
                payload["gas"] = random.randint(260, 420)
            else:
                payload["gas"] = random.randint(5, 20)

        return payload

    def trigger_smoke(self, cycles: int = 2) -> None:
        self.smoke_alert_cycles = cycles

    def trigger_gas(self, cycles: int = 2) -> None:
        if self.has_gas:
            self.gas_alert_cycles = cycles

    def summary(self, payload: dict) -> str:
        bits = [f"温度{payload.get('temperature')}℃", f"湿度{payload.get('humidity')}%"]
        if "aqi" in payload:
            bits.append(f"AQI{payload.get('aqi')}")
        bits.append(f"烟雾{payload.get('smoke')}ppm")
        if "gas" in payload:
            bits.append(f"燃气{payload.get('gas')}ppm")
        return " ".join(bits)


# ---------------------------------------------------------------------------
# 主模拟器
# ---------------------------------------------------------------------------
class DeviceSimulator:

    def __init__(self, client: BackendClient | None, cfg: configparser.ConfigParser,
                 dry_run: bool = False, enable_events: bool = True):
        self.client = client
        self.dry_run = dry_run
        self.enable_events = enable_events
        self.interval = cfg.getint("simulator", "interval", fallback=30)
        self.pir_probability = cfg.getfloat("simulator", "pir_probability", fallback=0.15)
        self.smoke_probability = cfg.getfloat("simulator", "smoke_probability", fallback=0.03)
        self.gas_probability = cfg.getfloat("simulator", "gas_probability", fallback=0.02)
        self.sensors: dict[int, RoomSensor] = {}
        self.device_cache: dict[int, dict] = {}     # device_id -> 上次看到的状态 JSON
        self.self_actions: dict[int, float] = {}    # device_id -> 我们下发动作的时间戳
        self.rooms: list = []

    # ---- 初始化 ----
    def load_rooms(self) -> None:
        if self.dry_run:
            # 不连后端时给两组假数据，方便离线看输出
            self.rooms = [{"id": 1, "name": "客厅"}, {"id": 2, "name": "厨房"}]
            has_gas_map = {1: False, 2: True}
        else:
            self.rooms = self.client.rooms()
            has_gas_map = {}
            for room in self.rooms:
                env = self.client.environment(room["id"])
                has_gas_map[room["id"]] = env.get("hasGas") == 1

        if not self.rooms:
            log("初始化", "后端没有任何房间 —— 先在 App 里建一个房间，或调 POST /api/room")
            sys.exit(1)

        for room in self.rooms:
            rid = room["id"]
            self.sensors[rid] = RoomSensor(rid, room.get("name", f"房间{rid}"),
                                           has_gas=has_gas_map.get(rid, False))
        log("初始化", f"接管 {len(self.sensors)} 个房间："
                     + "、".join(f"#{r['id']}-{r.get('name')}" for r in self.rooms))

    # ---- 一轮循环 ----
    def tick(self) -> None:
        for rid, sensor in self.sensors.items():
            payload = sensor.sample()
            if self.dry_run:
                log("采集(演练)", f"{sensor.name} → {json.dumps(payload, ensure_ascii=False)}")
            else:
                self.client.refresh_environment(rid, payload)
                log("上报", f"{sensor.name} → {sensor.summary(payload)}")

        self.echo_device_state()
        if self.enable_events:
            self.maybe_inject_events()

    # ---- 模拟"设备执行了 App 下发的指令" ----
    def echo_device_state(self) -> None:
        if self.dry_run:
            return
        for room in self.rooms:
            rid = room["id"]
            for dev in self.client.devices(rid):
                did = dev["id"]
                status = dev.get("status")
                prev = self.device_cache.get(did)
                if prev is not None and prev != status:
                    # 过滤掉我们刚刚自己下发的动作（比如人体感应开灯）
                    if time.time() - self.self_actions.get(did, 0) < 5:
                        self.device_cache[did] = status
                        continue
                    log("设备", f"{dev.get('name')} 状态已变更 → {status}（模拟执行完成）")
                self.device_cache[did] = status

    # ---- 随机事件：模拟 IS1 人体感应 / SF1 烟雾·燃气 ----
    def maybe_inject_events(self) -> None:
        # 人体感应 -> 回家自动开灯
        if random.random() < self.pir_probability:
            room = random.choice(self.rooms)
            lights = [d for d in self.client.devices(room["id"]) if d.get("type") == "light"]
            if lights:
                light = random.choice(lights)
                log("事件", f"人体感应（E53_IS1）：{room.get('name')}检测到有人 → 自动开灯 {light.get('name')}")
                self.self_actions[light["id"]] = time.time()
                self.client.control_device(light["id"], {"power": "on"})

        # 烟雾 -> 触发报警（后端阈值 50）
        if random.random() < self.smoke_probability:
            room = random.choice(self.rooms)
            self.sensors[room["id"]].trigger_smoke(2)
            log("事件", f"烟雾（E53_SF1）：{room.get('name')}浓度超阈 → 后端将置 smokeAlarm=1")

        # 燃气 -> 仅厨房类房间
        gas_rooms = [r for r in self.rooms if self.sensors[r["id"]].has_gas]
        if gas_rooms and random.random() < self.gas_probability:
            room = random.choice(gas_rooms)
            self.sensors[room["id"]].trigger_gas(2)
            log("事件", f"燃气（E53_SF1）：{room.get('name')}检测到泄漏 → 后端将置 gasAlarm=1")

    # ---- 运行 ----
    def run(self, once: bool = False) -> None:
        self.load_rooms()
        log("启动", f"模式={'演练(不发请求)' if self.dry_run else '真实上报'} "
                   f"间隔={self.interval}s 事件={'开' if self.enable_events else '关'}")
        try:
            while True:
                self.tick()
                if once:
                    break
                time.sleep(self.interval)
        except KeyboardInterrupt:
            log("退出", "收到 Ctrl+C，模拟器停止")


# ---------------------------------------------------------------------------
# 配置加载
# ---------------------------------------------------------------------------
DEFAULT_CONFIG = """\
[server]
# 后端地址。注意：后端默认端口 6893 被 WorkBuddy 占用，手动启动请用 --server.port=8080
base_url = http://127.0.0.1:8080
username = demo
password = 123456
timeout = 5

[simulator]
# 上报间隔（秒）。和后端 SensorSimTask 的 fixedRate=30000ms 对齐最自然
interval = 30
# 是否开启随机事件（人体感应/烟雾/燃气）
enable_events = true
# 每轮触发概率
pir_probability = 0.15
smoke_probability = 0.03
gas_probability = 0.02
"""


def load_config(path: str) -> configparser.ConfigParser:
    cfg = configparser.ConfigParser()
    if os.path.exists(path):
        cfg.read(path, encoding="utf-8")
    else:
        log("配置", f"未找到 {path}，使用内置默认值，并生成一份模板")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(DEFAULT_CONFIG)
        cfg.read_string(DEFAULT_CONFIG)
    return cfg


def main() -> None:
    parser = argparse.ArgumentParser(description="智慧家居设备模拟器（HTTP 版）")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.ini"),
                        help="配置文件路径")
    parser.add_argument("--once", action="store_true", help="只跑一轮后退出")
    parser.add_argument("--dry-run", action="store_true", help="不请求后端，只打印数据")
    parser.add_argument("--no-events", action="store_true", help="关闭随机事件")
    args = parser.parse_args()

    cfg = load_config(args.config)
    base_url = cfg.get("server", "base_url", fallback="http://127.0.0.1:8080")
    username = cfg.get("server", "username", fallback="demo")
    password = cfg.get("server", "password", fallback="123456")
    timeout = cfg.getfloat("server", "timeout", fallback=5.0)
    enable_events = cfg.getboolean("simulator", "enable_events", fallback=True) and not args.no_events

    client = None
    if not args.dry_run:
        client = BackendClient(base_url, username, password, timeout)

    sim = DeviceSimulator(client, cfg, dry_run=args.dry_run, enable_events=enable_events)
    sim.run(once=args.once)


if __name__ == "__main__":
    main()
