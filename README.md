# 米家风格智慧家居 App

> 技术栈：HarmonyOS ArkTS（ArkUI）｜ Spring Boot 3.3.4 ｜ MySQL 8 ｜ MyBatis-Plus 3.5.7
> 前端 23 个页面 + 8 个组件，后端 12 个 Controller / 54 个接口 / 4 个定时任务，数据库 16 张表；
> **能力闭环**：登录注册 → 房间与 17 种设备（含环境监测、定时任务）→ 场景自动化 → 产品库 → 商城下单。
> 配套文档在 `docs/` 目录，**动手前先读对应章节**。

---

## 一、目录结构

```text
smarthome_project/
├── smarthome_app/          # 前端（DevEco Studio 工程）
│   └── entry/src/main/ets/
│       ├── pages/          # 23 个页面文件（Index 启动页 + AdPage 广告页 + 5 个 Tab 页 + 16 个子页）
│       │                   #   Tab：主页 / 智能 / 产品 / 商城 / 我的
│       ├── view/           # 8 个可复用组件（设备卡片、环境网格、天气面板、房间选择器等）
│       ├── api/            # 6 个接口文件（所有 URL 只能出现在这里！）
│       ├── model/          # 6 个数据模型文件（与后端 VO 一一对应）
│       └── common/         # Env / Const / Format / TokenStore / HttpClient / DeviceOptions / AppFlag
├── smarthome_server/       # 后端（Maven 工程，IDEA 直接打开）
│   └── src/main/java/com/smarthome/
│       ├── controller/     # 12 个控制器（54 个端点，清单见 docs/03_接口文档.md）
│       ├── service/        # 12 个业务接口 + impl/ 12 个实现
│       ├── mapper/         # 16 个 Mapper（继承 BaseMapper）
│       ├── entity/         # 16 个实体（对应 16 张表）
│       ├── dto/ vo/        # 入参 12 个 / 出参 8 个
│       ├── common/         # Result / BizException / 全局异常 / DeviceTypes（设备字典唯一事实来源）/ JwtUtil
│       ├── config/         # LoginInterceptor / WebConfig（鉴权白名单）
│       ├── aspect/         # OpLogAspect（写操作自动落操作日志）
│       └── task/           # 4 个定时任务（SensorSim / SceneTimed / WaterTimed / DeviceTimed）
├── docs/
│   ├── 01_总方案.md        # 页面清单、接口清单、UI 规范、踩坑记录（先读第七/十一章）
│   ├── 02_开发手册_前端.md  # ArkTS 页面代码模板（先读 5.0 节）
│   ├── 02_开发手册_后端.md  # Spring Boot 三层代码模板
│   ├── 03_接口文档.md      # 前后端契约 + 命名规范（改接口必须先改这里）
│   ├── 04_数据库设计.md    # 16 张表设计说明
│   ├── 05_更新记录.md      # 骨架交付后的更新与新增（增量 / 原因 / 验证方式）
│   └── 06_项目总结报告_答辩.md # 答辩用一页通（功能清单 / 架构 / 亮点 / 验证）
├── Mysql/                  # init_all.sql：建库建表+演示数据（唯一需要执行的脚本，可单独交付）
└── README.md
```

---

## 二、环境搭建（每人开工前做一遍）

### 2.1 数据库

`Mysql/init_all.sql` 是**自包含的唯一脚本**（`smart_home` 库 + 全部演示数据），执行整个文件即可，导入方式任选：

```cmd
:: cmd 里（PowerShell 不支持 < 重定向）—— ⚠️ 必须带 --default-character-set=utf8mb4
cmd /c "mysql -u root -p --default-character-set=utf8mb4 < Mysql\init_all.sql"

:: 或进 mysql 后（先执行 SET NAMES utf8mb4;）
mysql> source D:/Code/smarthome_project/Mysql/init_all.sql

:: 或用 Navicat「运行 SQL 文件」（最省事，连接编码选 utf8mb4）
```

> ⚠️ **编码不看住，中文全变 `?`**：用命令行或 Navicat 导入时若不指定 utf8mb4，房间名/设备名/商品名会成批变成问号，
> 而且**无法用 UPDATE 还原**（信息已丢失），只能重新导入一次。演示前务必肉眼确认首页有中文。
>
> 想要干净演示态（清掉所有自测数据）就重跑一遍脚本：开头自带 `DROP DATABASE`，会重建 4 房间 / 19 设备 / 9 场景 / 20 商品 / 8 产品 / 7 轮播。

演示账号：`demo / 123456`。

### 2.2 后端

1. IDEA 打开 `smarthome_server` 目录；
2. 确认 `src/main/resources/application.yml` 里 `password` 是**你自己的 MySQL 密码**（当前是 `"123456"`，不对就改；含特殊字符必须用双引号包住）；
3. 运行 `SmartHomeApplication`；
4. 验证：浏览器开 `http://localhost:8080/api/user/info`，返回 `{"code":401,"msg":"请先登录"}` 即成功 ——
   能返回这段 JSON，说明「服务已启动 + 拦截器已生效 + 中文不乱码」三件事全对。

> ⚠️ **健康检查只认 `/api/user/info`**：它需要登录，未带 token 时返回 `{"code":401,"msg":"请先登录"}`。
> 别拿 `/api/product/categories` 之类的**公开接口**当健康检查——它们不带 token 也能通过，
> 后端没起来时你会看到连接被拒（Connection refused）而不是 401，容易判错。

**三条红线**：只允许启动一个实例（定时任务会双倍跑）；改完 yml 必须 Rebuild（Ctrl+F9）再重启；改 `.java` 后必须**重启进程**而不是只 Build（JVM 只在启动时加载 class）。

### 2.3 前端

1. DevEco Studio 打开 `smarthome_app`；
2. 修改 `entry/src/main/ets/common/Env.ets` 的 `BASE_URL_DEV` 为**后端电脑的局域网 IP**（`ipconfig` 查看；模拟器可用 `10.0.2.2`）；真机需与电脑同一 WiFi；
3. 网络权限 `ohos.permission.INTERNET` 已配好（`module.json5`），路由表已登记全部页面；
4. 直接运行即可编译通过：全部页面均已实现（广告启动页 → 首页 / 智能 / 商城 / 消息 / 我的 五个 Tab，
   设备详情、场景、订单、商品等子页齐全）。

> **当前状态（2026-09-30）**：全部业务模块已完成并通过两端编译 ——
> 登录/注册（含邮箱验证码注册）/我的、房间与 17 种设备（含环境监测、定时任务）、场景与自动化、
> 产品库、商城（商品/购物车/订单）、轮播图、天气、操作日志，后端 12 个 Controller / 55 个端点。
> **唯一未实现**：`PUT /api/user/profile`（修改昵称/头像，规划中）。

命令行编译验证（不开 DevEco 也能查错，见前端手册 5.0.3）：

```cmd
:: 路径按自己机器改：DEVECO_SDK_HOME 指向 DevEco 的 SDK 目录
:: （DevEco 里 File → Settings → SDK 能看到；本项目验证机上它是 C:\Users\LENOVO\ohossdk，
::   不是 DevEco 安装目录下的 sdk —— 指错会报 "SDK component missing"）
set DEVECO_SDK_HOME=<你的 SDK 目录>
cd smarthome_app
"D:\Soft\Huawei\DevEco Studio\tools\node\node.exe" "D:\Soft\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

> 末行出现 `BUILD SUCCESSFUL` 即通过。若报错信息"改了但不变"，在命令末尾加 `--no-daemon` 重编
> （hvigor 守护进程会缓存旧文件快照）。

---

## 三、骨架约定（先看再动手）

| 已写好（可直接用，不要重写） | 留白（TODO 注释标明做什么、看哪节） |
|---|---|
| `pom.xml`、`application.yml`、启动类 | 全部 entity / dto / vo 的字段声明 |
| `common/Result`、`BizException`、`GlobalExceptionHandler` | 全部 Service 接口方法与实现 |
| 全部 16 个 Mapper（继承 BaseMapper） | 全部 Controller 端点 |
| 前端 `Env.ets`、`Const.ets`、`color.json` | `JwtUtil`、`LoginInterceptor`、`WebConfig` |
| 路由表 `main_pages.json`、网络权限 | 前端 `TokenStore`、`HttpClient`、`Format` |
| 3 个定时任务类壳 | 全部 model / api / view / pages |

**每个骨架文件的注释里都写了**：这一步做什么、参考哪份文档哪一节、有哪些坑。照着 TODO 一条条来即可。

**通用纪律**（总方案 7.8 + 十一章，16 条踩坑都是真的）：

1. 目录/文件只用下划线 `_`，绝不用连字符；
2. 改完先 Ctrl+S（看标签页 `*` 号消失）再谈重启；
3. 一次只改一个文件，改完核对落盘再改下一个；
4. 报错先看 `Caused by:` 和第一条 `ERROR`，别看调用栈；
5. 改接口**先改 `03_接口文档.md` 再改代码**，并同步群里；
6. `catch` 兜底不许静默 return null，至少打一行日志；
7. ForEach 的 key 必须拼上**会变的数据**，不能只用 id；
8. 未登录不发需登录的请求、不起轮询；
9. 前端改完先编译再提交；后端改完必须重启进程。

---

## 四、学习路线（6 个阶段，验收标准见总方案第八章）

| 阶段 | 后端做什么 | 前端做什么 | 看哪份文档 |
|------|-----------|-----------|-----------|
| ① 骨架与登录 | `JwtUtil` → `LoginInterceptor`/`WebConfig` → User/Address 三层 | `TokenStore` → `HttpClient` → `UserApi` → 登录/注册页 → `MinePage` 两态 | 后端手册二三章；前端手册四五六章 |
| ② 设备主链路（里程碑） | Room/Device 三层 + control 状态合并 + 环境监测接口 + `SensorSimTask` | 首页 + `EnvironmentPanel` + 设备详情 + 添加设备 + 房间管理 | 后端手册四章；前端手册 6.1–6.4 |
| ③ 智能场景 | Scene 三层 + run 事务 + `SceneTimedTask` | 智能页 + 场景编辑 + 自动化详情 | 后端手册五章 |
| ④ 产品库 | Product 三层 + 初始化数据 | 产品页 + 产品详情（去商城跳转） | 后端手册六章 |
| ⑤ 商城闭环（里程碑） | Goods/Cart/Order 三层 + 模拟支付 | 商城页 + 详情 + 购物车 + 订单三页 + 支付两页 | 后端手册七章 |
| ⑥ 打磨交付 | 补数据、修 Bug | UI 统一、空态、录视频 | 总方案九/十章 |

> 建议节奏：每个阶段**后端先 Apifox/curl 自测通过**，前端再接——curl 自测命令见后端手册 1.7 节。

---

## 五、协作约定

- 分支：`main`（可运行）+ `feature/xxx`；提交信息 `feat:` / `fix:` / `docs:`；
- 接口改动流程：先改 `docs/03_接口文档.md` → 同步群里 → 再改代码；
- 联调互相不阻塞：前端可用 mock 数据先跑 UI（总方案 7.2）。
