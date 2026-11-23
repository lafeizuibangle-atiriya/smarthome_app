package com.smarthome.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 华为云 IoTDA 对接配置（application.yml 的 huawei.iot 段）。
 *
 * <p>【取值来源】
 * <ul>
 *   <li>endpoint：固定 https://iotda.cn-east-3.myhuaweicloud.com（上海一）</li>
 *   <li>project-id：控制台右上角「我的凭证」→ 项目列表 cn-east-3 对应的 ID</li>
 *   <li>iam 三件套：IAM 子用户的账号域名 / 用户名 / 密码（换 token 用，不暴露给 App）</li>
 *   <li>device-id：实训箱那台设备的完整 ID（如 6adeb977e094d615927cf782_SmartHome_dev）</li>
 * </ul>
 * enabled=false 时华为云相关任务全部静默跳过，系统退回纯模拟模式。
 */
@Data
@Component
@ConfigurationProperties(prefix = "huawei.iot")
public class HuaweiIoTProperties {

    /** 总开关：凭证没填好之前保持 false，云端轮询与命令转发都不会执行 */
    private boolean enabled = false;

    /** 应用侧 API 入口 */
    private String endpoint = "https://iotda.cn-east-3.myhuaweicloud.com";

    /** 区域，token 请求的 scope 用 */
    private String region = "cn-east-3";

    /** 项目 ID（我的凭证页里查） */
    private String projectId = "";

    /** IAM 账号域名（主账号名） */
    private String iamDomainName = "";

    /** IAM 用户名 */
    private String iamUserName = "";

    /** IAM 密码 */
    private String iamPassword = "";

    /** 设备 ID（实训箱） */
    private String deviceId = "";

    /** 物模型服务名（Smart_Home_Demo 的产品定义） */
    private String serviceId = "smart_home";

    // ---------- AMQP 订阅（实时推送，替代 3 秒轮询，2026-11-19） ----------

    /** 应用侧接入域名（总览→接入信息→应用侧，形如 xxx.st1.iotda-app.cn-east-3...） */
    private String amqpHost = "";

    /** AMQP 接入凭证 accessKey（应用管理→应用→接入凭证） */
    private String amqpAccessKey = "";

    /** AMQP 接入凭证 accessCode */
    private String amqpAccessCode = "";

    /** AMQP 队列名（默认 DefaultQueue，一般不用改） */
    private String amqpQueueName = "DefaultQueue";

    /** AMQP 凭证是否齐全：齐全则走推送模式，3 秒轮询自动停用 */
    public boolean isAmqpReady() {
        return amqpHost != null && !amqpHost.isEmpty() && !amqpHost.startsWith("请填")
                && amqpAccessKey != null && !amqpAccessKey.isEmpty() && !amqpAccessKey.startsWith("请填")
                && amqpAccessCode != null && !amqpAccessCode.isEmpty() && !amqpAccessCode.startsWith("请填");
    }

    /** 凭证是否齐全（齐全且 enabled 才真正开始对接） */
    public boolean isReady() {
        return enabled
                && projectId != null && !projectId.isEmpty() && !projectId.startsWith("请填")
                && iamDomainName != null && !iamDomainName.isEmpty() && !iamDomainName.startsWith("请填")
                && iamUserName != null && !iamUserName.isEmpty() && !iamUserName.startsWith("请填")
                && iamPassword != null && !iamPassword.isEmpty() && !iamPassword.startsWith("请填")
                && deviceId != null && !deviceId.isEmpty() && !deviceId.startsWith("请填");
    }
}
