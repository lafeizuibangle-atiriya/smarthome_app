# Docker 容器化与监控部署笔记（智慧家居后端）

> 记录日期：2026-11-23。用途：作品集 / 复习材料。环境说明：开发机未装 Docker Desktop，容器在开发机上未实际运行；所有配置文件按标准写法给出，并在文末标注"待首次部署验证"的检查点。

## 1. 容器化要解决的问题

手动部署的三个痛点：
1. 环境不一致：开发机 JDK17/MySQL8/Redis3（Windows 版），演示机器版本可能不同；
2. 启动顺序靠人记：Redis 忘了启动，下单幂等就静默失效（压测时真实遇到过）；
3. 数据初始化靠文档：新机器要先跑 init_all.sql、改配置文件里三个地址。

容器化把这三件事交给声明式配置：版本锁在镜像 tag、顺序交给 healthcheck + depends_on、初始化交给挂载的 SQL。

## 2. Dockerfile 设计要点（多阶段构建）

```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS build   # 阶段1：编译
FROM eclipse-temurin:17-jre-alpine           # 阶段2：只带 JRE 运行
```

- **为什么多阶段**：最终镜像里没有 Maven、没有源码、没有依赖缓存，从 600MB+ 的构建环境缩到约 180MB 的运行环境。
- **依赖分层缓存**：先 `COPY pom.xml` + `mvn dependency:go-offline`，再 `COPY src`。改代码重建时 pom 层命中缓存，不用重新下载几百个依赖——这是 Spring 项目 Docker 构建提速的关键一步。
- **国内镜像**：构建阶段写入阿里云 Maven settings（`mirrorOf: *`），否则容器内拉依赖慢且常断。
- **时区**：`TZ=Asia/Shanghai` + tzdata，否则容器日志时间差 8 小时，排查问题会先怀疑人生。
- **HEALTHCHECK**：curl `/actuator/health` 判 UP。compose 的 `depends_on.condition: service_healthy` 和 Grafana 面板都依赖它。

## 3. docker-compose 编排设计

五个服务：`mysql + redis + app + prometheus + grafana`，要点：

- **网络互通用服务名**：app 里连数据库写 `DB_HOST: mysql` 而不是 localhost——容器之间各自有自己的网络命名空间，localhost 是容器自己。这是新人配置时容易忽略的一点。
- **配置外部化**：application.yml 里数据库/Redis 地址改成 `${DB_HOST:localhost}` 形式，冒号后是本地默认值。同一份代码：IDEA 直接跑用默认值，compose 里用环境变量覆盖，不用维护两份配置。
- **健康检查串联启动顺序**：mysql 用 `mysqladmin ping` 探活，app 的 `depends_on.condition: service_healthy` 保证 MySQL "真的能连了"才启动 app。只用 `depends_on`（不带 condition）只保证"容器启动了"，MySQL 还在初始化时 app 会连库失败进入 restart 循环。
- **数据持久化**：mysql_data / prometheus_data / grafana_data 三个命名卷，`down` 不丢数据，`down -v` 才删。
- **数据库自动初始化**：把 `init_all.sql` 挂到 `/docker-entrypoint-initdb.d/`，MySQL 镜像首次启动自动执行（注意：只在数据卷为空时执行一次，已有数据不会重跑）。
- **端口冲突预案**：主机已有 MySQL 时把映射改 `"3307:3306"`，容器内互访不受影响。
- **MySQL 字符集**：`--character-set-server=utf8mb4`，中文设备名/订单收货人不乱码。

## 4. 监控链路：Actuator → Prometheus → Grafana

### 4.1 数据怎么流

```
Spring Boot(/actuator/prometheus 暴露文本指标)
   ↑ Prometheus 每 15s 来抓
Prometheus(TSDB 存储)
   ↑ Grafana 查询 Prometheus 做图
Grafana(面板)
```

### 4.2 Spring Boot 侧

1. pom 加两个依赖：`spring-boot-starter-actuator`（端点）+ `micrometer-registry-prometheus`（把指标转成 Prometheus 文本格式）；
2. application.yml：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus   # 默认只开 health，prometheus 必须显式开
  metrics:
    tags:
      application: smarthome-server       # 指标打上应用标签，多应用时面板里过滤用
```

3. 关键点：登录拦截器拦 `/api/**`，actuator 端点在 `/actuator/**` 下天然放行，不用改白名单；`show-details: never` 避免把数据库/Redis 连接细节暴露出去。

### 4.3 Prometheus 侧

`prometheus.yml` 核心是抓取目标写 compose 服务名 `app:8080`（不是 localhost），抓取路径 `/actuator/prometheus`。挂载进容器 `/etc/prometheus/prometheus.yml`。

### 4.4 Grafana 侧（不用手画面板）

- 数据源：URL 填 `http://prometheus:9090`（容器网络内）；
- 面板直接 Import 社区 ID：**4701**（Spring Boot Statistics：JVM 内存/GC/线程）和 **19004**（Spring Boot API：按 uri 的 QPS/耗时 P95）；
- 最有信息量的几个指标：
  - `http_server_requests_seconds_count` —— 接口 QPS（按 uri/ status 标签分组）；
  - `hikaricp_connections_active` —— 连接池活跃数（压测时看它是否顶满，验证上次 HikariCP 10→20 调优的效果）；
  - `jvm_memory_used_bytes` / `jvm_gc_pause_seconds` —— 内存与 GC 停顿。

## 5. 配套文件清单

| 文件 | 作用 |
|---|---|
| `smarthome_server/Dockerfile` | 多阶段构建（Maven 编译 → JRE 运行） |
| `smarthome_server/.dockerignore` | 排除 target/、日志、临时文件 |
| `smarthome_server/deploy/prometheus.yml` | 抓取配置 |
| `docker-compose.yml`（工程根） | 五服务编排 + 卷 + 网络 |
| `Mysql/init_all.sql` | MySQL 容器首次启动自动初始化 |

## 6. 首次部署验证清单（拿到有 Docker 的机器时执行）

1. `docker compose up -d` → `docker compose ps` 五个服务 Up / healthy；
2. `curl localhost:8080/actuator/health` → UP；
3. 登录接口拿 token，App 连 8080 全功能回归一遍（对照 16_验收单）；
4. Grafana 导入 4701，压一轮 JMeter 看面板曲线变化；
5. `docker compose down && up -d` 后数据仍在（验证卷）；
6. 如 MySQL 端口冲突，按部署手册 1.4 改 3307。

## 7. 过程记录

- 本机验证的部分：actuator 依赖编译通过，`/actuator/health` 与 `/actuator/prometheus` 端点本机启动后实测正常返回（指标文本可见 jvm_/hikaricp_/http_server_requests_ 系列）；
- 意外收获：actuator 的 health 会探测 Redis——Redis 没启动时 `/actuator/health` 返回 DOWN，启动后转 UP。这正好让 Docker healthcheck 能感知"Redis 挂了"这种下游故障，比单纯探进程存活有价值；
- 改完配置全量回归：Pytest 59 条用例全部通过（1.97s），确认环境变量占位与 actuator 配置不影响既有功能；
- 本机未验证的部分：镜像构建与容器编排（无 Docker 环境），首次部署按第 6 节清单逐项执行即可。
