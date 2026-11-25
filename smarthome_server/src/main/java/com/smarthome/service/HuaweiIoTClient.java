package com.smarthome.service;

import cn.hutool.http.HttpRequest;
import cn.hutool.http.HttpResponse;
import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.smarthome.common.DeviceTypes;
import com.smarthome.config.HuaweiIoTProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 华为云 IoTDA 应用侧客户端（软件 ↔ 硬件的"翻译官"）。
 *
 * <p>三个能力：
 * <ol>
 *   <li>{@link #getToken()} —— IAM 用户名密码换 token，缓存 20 小时自动重取（token 有效期 24h）</li>
 *   <li>{@link #queryProperties()} —— 查询设备最新上报属性（上行：硬件 → 数据库）</li>
 *   <li>{@link #sendPowerCommand(String, boolean)} —— 下发开关命令（下行：App → 硬件）</li>
 * </ol>
 *
 * <p>【命令映射】与 Smart_Home_Demo 固件 HW_ApplyCommand() 的识别规则一字不差：
 * light→Light_control(Light) / fan→Motor_control(Motor) /
 * gate→Servo_control(Servo) / beep→Beep_control(Beep)。
 *
 * <p>【为什么不用 AK/SK 签名】签名流程复杂（规范请求头 + 派生密钥），课程作业用
 * IAM 用户名密码换 token 足够，且凭证只存在于后端配置文件，不进 App。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class HuaweiIoTClient {

    private final HuaweiIoTProperties props;

    /** 缓存的 token；null = 还没取过 */
    private volatile String token;

    /** token 取得时间（毫秒），用于 20 小时自动刷新 */
    private volatile long tokenAt = 0;

    /** token 有效期 24 小时，留 4 小时余量提前刷新 */
    private static final long TOKEN_TTL_MS = 20L * 60 * 60 * 1000;

    // ==================== 上行：查设备属性 ====================

    /**
     * 标准版实例网关要求查属性必须带 service_id。
     * 实测产品模型只有 smart_home 一个服务，所有属性（Lux/Temperature/各状态）都在它下面。
     */
    private static final String PROPERTIES_SERVICE = "smart_home";

    /**
     * 查询设备最新上报属性，把所有服务的 properties 合并成一个扁平 Map 返回。
     * 设备离线 / 网络失败 / 未启用时返回 null（调用方自行判断，不抛异常）。
     */
    public Map<String, Object> queryProperties() {
        if (!props.isReady()) {
            return null;
        }
        try {
            Map<String, Object> flat = new LinkedHashMap<>();
            String url = props.getEndpoint() + "/v5/iot/" + props.getProjectId()
                    + "/devices/" + props.getDeviceId()
                    + "/properties?service_id=" + PROPERTIES_SERVICE;
            HttpResponse resp = HttpRequest.get(url)
                    .header("X-Auth-Token", getToken())
                    .timeout(8000)
                    .execute();
            if (!resp.isOk()) {
                log.warn("[华为云] 查询属性失败 HTTP {}：{}", resp.getStatus(), resp.body());
                return null;
            }
            JSONObject body = JSONUtil.parseObj(resp.body());
            JSONArray services = body.getJSONArray("services");
            if (services == null || services.isEmpty()) {
                return null;                        // 设备还没上报过
            }
            JSONObject properties = services.getJSONObject(0).getJSONObject("properties");
            if (properties != null) {
                flat.putAll(properties);
            }
            return flat.isEmpty() ? null : flat;
        } catch (Exception e) {
            log.warn("[华为云] 查询属性异常：{}", e.getMessage());
            return null;
        }
    }

    // ==================== 下行：发开关命令 ====================

    /**
     * 按设备类型下发开关命令。power=true 发 ON，false 发 OFF。
     * 返回是否下发成功；未启用 / 类型不支持时返回 false（不抛异常）。
     */
    public boolean sendPowerCommand(String deviceType, boolean power) {
        String[] cmd = powerCommandOf(deviceType);
        if (cmd == null) {
            return false;
        }
        Map<String, Object> paras = new LinkedHashMap<>();
        paras.put(cmd[1], power ? "ON" : "OFF");
        // 注意：service_id 是产品模型里"定义了这条命令的服务"。
        // 实测拉取产品模型确认：所有命令都定义在唯一的 smart_home 服务下
        // （而不是 Light_control 等同名服务），所以这里用 props.getServiceId()。
        return sendCommand(props.getServiceId(), cmd[0], paras);
    }

    /**
     * 类型 → (command_name, 参数名)。固件侧 HW_ApplyCommand 只认这些名字。
     * smoke_sensor 没有命令（阈值在固件里烧死），返回 null。
     */
    private String[] powerCommandOf(String type) {
        if (DeviceTypes.LIGHT.equals(type)) return new String[]{"Light_control", "Light"};
        if (DeviceTypes.FAN.equals(type))    return new String[]{"Motor_control", "Motor"};
        if (DeviceTypes.GATE.equals(type))   return new String[]{"Servo_control", "Servo"};
        if (DeviceTypes.BEEP.equals(type))   return new String[]{"Beep_control", "Beep"};
        return null;
    }

    /**
     * 下发全屋自动/手动模式切换（2026-11-25 对齐固件，改走设备消息）。
     *
     * <p>固件不认 Mode_control 命令——它的模式识别在 esp8285.c 的串口中断回调里，
     * 对 messages 主题收到的报文原文做 strstr：包含 "smart_auto" → smart_flag=1（自动），
     * 包含 "smart_hand" → smart_flag=0（手动）。所以这里不能走命令接口，
     * 要走设备消息接口下发纯文本，云平台会投到固件订阅的 messages/down 主题。
     *
     * <p>固件没有 ModeStatus 属性上报，切完不会回传真实状态，
     * 库里的值以本方法调用方的乐观写入为准（见 DeviceServiceImpl.setMode）。
     */
    public boolean sendModeCommand(boolean auto) {
        return sendMessage(auto ? "smart_auto" : "smart_hand");
    }

    /**
     * 下发设备消息：POST /v5/iot/{projectId}/devices/{deviceId}/messages，
     * body 只有一个 message 字段装纯文本。
     */
    private boolean sendMessage(String text) {
        if (!props.isReady()) {
            return false;
        }
        try {
            JSONObject body = new JSONObject();
            body.set("message", text);

            String url = props.getEndpoint() + "/v5/iot/" + props.getProjectId()
                    + "/devices/" + props.getDeviceId() + "/messages";
            HttpResponse resp = HttpRequest.post(url)
                    .header("X-Auth-Token", getToken())
                    .body(body.toString())
                    .timeout(8000)
                    .execute();
            if (!resp.isOk()) {
                log.warn("[华为云] 消息下发失败 [{}] HTTP {}：{}", text, resp.getStatus(), resp.body());
                return false;
            }
            log.info("[华为云] 模式消息已下发 [{}] → 设备 {}", text, props.getDeviceId());
            return true;
        } catch (Exception e) {
            log.warn("[华为云] 消息下发异常 [{}]：{}", text, e.getMessage());
            return false;
        }
    }

    /** 通用命令下发：POST /v5/iot/{projectId}/devices/{deviceId}/commands */
    private boolean sendCommand(String serviceId, String commandName, Map<String, Object> paras) {
        if (!props.isReady()) {
            return false;
        }
        try {
            JSONObject body = new JSONObject();
            body.set("service_id", serviceId);
            body.set("command_name", commandName);
            body.set("paras", paras);

            String url = props.getEndpoint() + "/v5/iot/" + props.getProjectId()
                    + "/devices/" + props.getDeviceId() + "/commands";
            HttpResponse resp = HttpRequest.post(url)
                    .header("X-Auth-Token", getToken())
                    .body(body.toString())
                    .timeout(8000)
                    .execute();
            if (!resp.isOk()) {
                log.warn("[华为云] 命令下发失败 {} HTTP {}：{}", commandName, resp.getStatus(), resp.body());
                return false;
            }
            log.info("[华为云] 命令已下发 {} paras={} → 设备 {}", commandName, paras, props.getDeviceId());
            return true;
        } catch (Exception e) {
            log.warn("[华为云] 命令下发异常 {}：{}", commandName, e.getMessage());
            return false;
        }
    }

    // ==================== IAM token ====================

    /**
     * 取 token：缓存未过期直接用；否则用 IAM 用户名密码重新换一个。
     * 失败返回 null 并打日志（调用方按失败处理）。
     */
    private synchronized String getToken() {
        if (token != null && System.currentTimeMillis() - tokenAt < TOKEN_TTL_MS) {
            return token;
        }

        // 1) 组装 IAM v3 token 请求体
        JSONObject user = new JSONObject();
        user.set("domain", new JSONObject().set("name", props.getIamDomainName()));
        user.set("name", props.getIamUserName());
        user.set("password", props.getIamPassword());

        JSONObject identity = new JSONObject();
        identity.set("methods", new String[]{"password"});
        identity.set("password", new JSONObject().set("user", user));

        JSONObject scope = new JSONObject();
        scope.set("project", new JSONObject().set("name", props.getRegion()));

        JSONObject auth = new JSONObject();
        auth.set("identity", identity);
        auth.set("scope", scope);

        JSONObject req = new JSONObject();
        req.set("auth", auth);

        // 2) 请求：token 在响应头 X-Subject-Token 里
        HttpResponse resp = HttpRequest.post("https://iam.myhuaweicloud.com/v3/auth/tokens")
                .header("Content-Type", "application/json")
                .body(req.toString())
                .timeout(8000)
                .execute();
        if (!resp.isOk()) {
            log.error("[华为云] IAM 换 token 失败 HTTP {}：{}", resp.getStatus(), resp.body());
            return null;
        }
        token = resp.header("X-Subject-Token");
        tokenAt = System.currentTimeMillis();
        log.info("[华为云] IAM token 获取成功，缓存 20 小时");
        return token;
    }
}
