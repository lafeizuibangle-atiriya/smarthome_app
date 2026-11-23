# ============================================================
# 智慧家居后端镜像（多阶段构建）
# 构建阶段：Maven + JDK17 编译打包（阿里云镜像源加速依赖下载）
# 运行阶段：JRE17 精简镜像，只带 jar
# 用法见 docker-compose.yml，或单独构建：
#   docker build -t smarthome-server:1.0 .
# ============================================================

# ---------- 阶段 1：编译打包 ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# 用阿里云 Maven 镜像（依赖下载快且稳定，国内构建必配）
RUN mkdir -p /root/.m2 && printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0">' \
    '  <mirrors>' \
    '    <mirror>' \
    '      <id>aliyun</id>' \
    '      <mirrorOf>*</mirrorOf>' \
    '      <url>https://maven.aliyun.com/repository/public</url>' \
    '    </mirror>' \
    '  </mirrors>' \
    '</settings>' > /root/.m2/settings.xml

# 先只拷 pom 拉依赖：pom 不变时这层走缓存，改代码重新构建不用重新下载依赖
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# 再拷源码编译
COPY src ./src
RUN mvn package -B -q -DskipTests

# ---------- 阶段 2：运行 ----------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# 容器时区（不设的话日志时间会差 8 小时）
ENV TZ=Asia/Shanghai
RUN apk add --no-cache tzdata curl \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

COPY --from=build /app/target/smarthome_server-1.0.0.jar app.jar

EXPOSE 8080

# 健康检查：Prometheus 面板和 compose 的 depends_on 都依赖这个
HEALTHCHECK --interval=15s --timeout=5s --start-period=40s --retries=5 \
    CMD curl -fs http://localhost:8080/actuator/health | grep -q UP

ENTRYPOINT ["java", "-jar", "app.jar"]
