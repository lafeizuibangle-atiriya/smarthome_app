# 设备模拟器（device_simulator）

在没有真实硬件时，冒充"设备端"给后端喂数据。**模拟器和真板子走同一套后端接口**，所以等 BearPi 到货后可以直接替换，后端一行都不用改。

## 它做了什么

1. **环境上报**：按 E53_IA1 的物理模型，每 30 秒给每个房间上报温湿度、AQI、CO₂、烟雾（数值随机游走，不会突变）。
2. **随机事件**：
   - **人体感应（E53_IS1）**：随机触发 → 找到同房间的 `light` 设备 → 自动开灯（模拟"回家自动亮灯"）。
   - **烟雾（E53_SF1）**：随机给高浓度 → 后端自动置 `smokeAlarm=1`。
   - **燃气（E53_SF1）**：仅在 `hasGas=1` 的房间（厨房）触发。
3. **指令回显**：轮询设备状态，发现 App 下发了控制指令就打印一行"模拟执行完成"，让你在终端里看到指令真的到达了"设备"。

## 数据映射

| E53 板 | 后端字段 |
|---|---|
| IA1 温湿度 | `temperature` / `humidity` |
| IA1 光照 | `aqi` / `co2`（演示推导，非真实值） |
| SF1 烟雾 | `smoke`（阈值为 50，超过后端自动报警） |
| SF1 燃气 | `gas`（仅 `hasGas=1` 的房间） |
| IS1 人体红外 | 无对应字段 → 转成"自动开灯"动作 |

## 快速开始

```bash
# 1) 装依赖（走清华镜像，快）
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 2) 先演练一遍，不连后端，只看会发什么数据
python device_simulator.py --dry-run --once

# 3) 后端起来之后，真连
python device_simulator.py
```

## 前置条件

- **后端已启动**。注意默认端口 6893 被 WorkBuddy 占用，手动启动要指定端口：
  ```bash
  ./mvnw spring-boot:run -Dspring-boot.run.arguments=--server.port=8080
  ```
- **改 `config.ini` 里的 `username` / `password`** 为你 App 里真实注册过的账号（模拟器靠它登录拿 token）。
- **后端里至少有一个房间**，否则模拟器会提示你先生成房间。

## 参数

| 参数 | 说明 |
|---|---|
| `--once` | 只跑一轮后退出（验证链路用） |
| `--dry-run` | 不请求后端，只打印将发送的数据 |
| `--no-events` | 关闭随机事件，只看平稳数据 |
| `--config x.ini` | 指定配置文件 |

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `登录失败` | `config.ini` 的账号密码不对，或后端没启动 |
| `后端没有任何房间` | 先在 App 里建房间 |
| `缺少 requests 库` | `pip install -r requirements.txt` |
| 中文乱码 | Windows 终端执行 `chcp 65001` 切 UTF-8 |
| 数据每 30 秒抖两次 | 后端自带 `SensorSimTask` 也在抖。模拟器上报的值会覆盖它，无害；想让一方说话就把间隔错开 |

## 和真板子的关系

等 BearPi-HM Nano / IoT Std 到货后，把 `refresh_environment()` 对应的 HTTP 请求用 C 写进固件（Hi3861 走 WiFi、Std 走网口/WiFi 板），上报同一个 `/api/room/{roomId}/environment/refresh` 接口即可。届时这个 Python 脚本可以留着当**压测/兜底**用（答辩现场设备掉线时顶上）。
