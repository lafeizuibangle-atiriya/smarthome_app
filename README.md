# 米家风格智慧家居 App

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-Next-0A59F7)
![ArkTS](https://img.shields.io/badge/ArkTS-5-lime)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.3.4-6db33f)
![MySQL](https://img.shields.io/badge/MySQL-8-4479a1)
![MyBatis-Plus](https://img.shields.io/badge/MyBatis--Plus-3.5.7-blue)

一套可直接运行的智慧家居系统：HarmonyOS 客户端 + Spring Boot 服务端 + MySQL 数据库，配套 STM32 硬件固件。项目主体已完成，前端 23 个页面 / 8 个组件，后端 12 个 Controller / 55 个接口 / 4 个定时任务，数据库 16 张表。

技术栈：HarmonyOS ArkTS（ArkUI）｜ Spring Boot 3.3.4 ｜ MyBatis-Plus 3.5.7 ｜ MySQL 8 ｜ JWT。

硬件固件仓库：`smarthome_firmware`（STM32L431 + ESP8285 + MQTT 接入华为云 IoTDA）。设计与实现文档在 `docs/` 目录。

---

## 一、功能

**账户**
- 登录、注册（邮箱验证码）、退出，JWT 鉴权，未登录请求被拦截器拦截。
- 我的页面：用户信息、收货地址、操作日志查看。

**房间与设备**
- 4 个房间，17 种设备：灯、风扇、空调、窗帘、插座、门锁、摄像头、烟雾报警器、人体感应等。
- 设备开关、档位/温度/亮度调节、状态回显；房间切换与设备增删改。
- 环境监测：光照、温湿度、烟雾、人体感应数据展示，由后端定时任务模拟生成。
- 设备定时任务：按设定时间自动开关。

**场景自动化**
- 场景创建与编辑，一个场景绑定多个设备动作。
- 手动执行与定时触发两种方式；条件满足时事务内批量下发设备状态。

**产品库与商城**
- 产品分类、产品详情，可从产品页跳转商城。
- 商品列表、商品详情、购物车、订单与模拟支付流程。
- 首页轮播图、天气面板。

**后台能力**
- 操作日志：写操作通过切面自动记录。
- 4 个定时任务：传感器模拟、场景定时、浇水定时、设备定时。

---

## 二、技术实现

**架构**：前端负责界面与交互，所有请求经 `HttpClient` 统一处理 token 与错误；后端按 Controller / Service / Mapper / Entity 分层，通用返回体 `Result` 与全局异常处理器统一响应格式；MySQL 存储业务数据，MyBatis-Plus 负责数据访问。

**鉴权**：JWT 签发与校验封装在 `JwtUtil`；`LoginInterceptor` 拦截需登录接口，`WebConfig` 配置白名单；前端 `TokenStore` 管理 token 存取，路由未登录时跳转登录页。

**设备模型**：`DeviceTypes` 是设备类型的唯一字典来源，前端 `DeviceOptions` 与之一一对应，避免两端类型定义不一致。

**场景执行**：运行场景时在一个数据库事务内更新多个设备状态并写日志，中途失败整体回滚。

**定时任务**：Spring `@Scheduled` 驱动，传感器任务按周期写入监测数据，其余任务按设定时间触发设备动作或场景。

**前后端契约**：所有接口定义与字段约定写在 `docs/03_接口文档.md`，改接口先改文档再改代码；前端 `api/` 目录集中放置请求地址，不散落在页面中。

---

## 三、目录结构

```text
smarthome_app/
├── smarthome_app/          # 前端（DevEco Studio 工程）
│   └── entry/src/main/ets/
│       ├── pages/          # 23 个页面（启动/广告页 + 首页/智能/商城/消息/我的 5 个 Tab + 子页）
│       ├── view/           # 8 个可复用组件（设备卡片、环境网格、天气面板、房间选择器等）
│       ├── api/            # 6 个接口文件（所有 URL 只出现在这里）
│       ├── model/          # 6 个数据模型（与后端 VO 对应）
│       └── common/         # Env / Const / Format / TokenStore / HttpClient / DeviceOptions / AppFlag
├── smarthome_server/       # 后端（Maven 工程）
│   └── src/main/java/com/smarthome/
│       ├── controller/     # 12 个控制器，55 个端点
│       ├── service/        # 12 个业务接口及实现
│       ├── mapper/         # 16 个 Mapper，继承 BaseMapper
│       ├── entity/         # 16 个实体，对应 16 张表
│       ├── dto/ vo/        # 入参 / 出参对象
│       ├── common/         # Result / BizException / 全局异常处理 / DeviceTypes / JwtUtil
│       ├── config/         # LoginInterceptor / WebConfig
│       ├── aspect/         # OpLogAspect，写操作自动记录日志
│       └── task/           # 4 个定时任务
├── docs/
│   ├── 01_总方案.md        # 页面清单、接口清单、UI 规范、问题记录
│   ├── 02_开发手册_前端.md  # ArkTS 页面与组件的实现说明
│   ├── 02_开发手册_后端.md  # Spring Boot 分层实现说明
│   ├── 03_接口文档.md      # 前后端接口契约与命名规范
│   ├── 04_数据库设计.md    # 16 张表的设计说明
│   ├── 05_更新记录.md      # 功能增量与验证记录
│   └── 06_项目总结报告_答辩.md
├── Mysql/                  # init_all.sql：建库建表 + 演示数据
└── README.md
```

---

## 四、运行方式

### 4.1 导入数据库

`Mysql/init_all.sql` 是自包含脚本（`smart_home` 库 + 全部演示数据），执行整个文件即可：

```cmd
:: cmd 中执行（PowerShell 不支持 < 重定向）；需指定 utf8mb4
cmd /c "mysql -u root -p --default-character-set=utf8mb4 < Mysql\init_all.sql"

:: 或进入 mysql 后执行
mysql> source <项目目录>/Mysql/init_all.sql

:: 或用 Navicat「运行 SQL 文件」，连接编码选 utf8mb4
```

导入时不指定 utf8mb4，房间名、设备名、商品名的中文会变成问号且无法用 UPDATE 还原，只能重新导入。演示前确认首页中文显示正常。

脚本开头带 `DROP DATABASE`，重跑会重建演示数据：4 房间 / 19 设备 / 9 场景 / 20 商品 / 8 产品 / 7 轮播。

演示账号：`demo / 123456`。

### 4.2 启动后端

1. IDEA 打开 `smarthome_server` 目录；
2. 确认 `src/main/resources/application.yml` 里的 MySQL 密码与本机一致（默认是 `123456`；含特殊字符要加双引号）；
3. 运行 `SmartHomeApplication`；
4. 浏览器访问 `http://localhost:8080/api/user/info`，返回 `{"code":401,"msg":"请先登录"}` 即表示服务、拦截器和中文编码都正常。

启动时只运行一个实例，否则定时任务会重复执行；改完 yml 需要 Rebuild 再重启，改完 `.java` 需要重启进程而不是只 Build。

### 4.3 运行前端

1. DevEco Studio 打开 `smarthome_app` 目录；
2. 修改 `entry/src/main/ets/common/Env.ets` 的 `BASE_URL_DEV` 为后端所在机器的局域网 IP（`ipconfig` 可查；模拟器用 `10.0.2.2`），真机需与电脑在同一 WiFi；
3. 网络权限 `ohos.permission.INTERNET` 已配置，路由表已登记全部页面；
4. 直接运行即可。

命令行编译验证（不需要打开 DevEco）：

```cmd
set DEVECO_SDK_HOME=<DevEco SDK 目录，本项目验证机上是 C:\Users\LENOVO\ohossdk>
cd smarthome_app
"D:\Soft\Huawei\DevEco Studio\tools\node\node.exe" "D:\Soft\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

末行出现 `BUILD SUCCESSFUL` 即通过。若改了文件但编译结果不变，在命令末尾加 `--no-daemon` 重编，避免守护进程使用旧文件快照。

---

## 五、完成情况

- 前后端均已通过编译：登录/注册（邮箱验证码）、房间与 17 种设备、环境监测、设备定时任务、场景与自动化、产品库、商城（商品/购物车/订单）、轮播图、天气、操作日志。
- 后端 12 个 Controller / 55 个接口；接口清单见 `docs/03_接口文档.md`。
- 待实现：`PUT /api/user/profile`（修改昵称/头像）。
