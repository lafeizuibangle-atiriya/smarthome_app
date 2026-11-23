package com.smarthome.service;

import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.DeviceTypes;
import com.smarthome.config.HuaweiIoTProperties;
import com.smarthome.entity.Device;
import com.smarthome.entity.Room;
import com.smarthome.entity.RoomEnvironment;
import com.smarthome.entity.SystemConfig;
import com.smarthome.mapper.DeviceMapper;
import com.smarthome.mapper.RoomEnvironmentMapper;
import com.smarthome.mapper.RoomMapper;
import com.smarthome.mapper.SystemConfigMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 华为云设备数据同步（上行链路的核心逻辑，轮询与 AMQP 推送两个入口共用）。
 *
 * <p>入口一（轮询）：HuaweiSyncTask 每 3 秒查一次 REST 接口，取扁平属性 Map，
 * 调 {@link #syncProperties(Map)}。AMQP 配好后的回退方案。
 * <p>入口二（推送，推荐）：HuaweiAmqpClient 建一条 AMQP 长连接，平台在设备上报的
 * 瞬间把报文推过来，调 {@link #handlePushMessage(String)}，秒级到达、零轮询请求。
 *
 * <p>两种入口最终都落到同一套写库逻辑（本类私有方法），【2026-11-19 对齐硬件】后：
 * <ul>
 *   <li>LightStatus / MotorStatus / ServoStatus / BeepStatus → 对应设备 status.power
 *       （App 控制与硬件自动模式的开关状态双向一致）</li>
 *   <li>SmokeStatus（ON=有烟/OFF=正常）→ 烟雾传感器设备的 smoke 展示值 + alarm 报警位</li>
 *   <li>PIR_Status（ON/OFF）→ 人体感应设备的 present（有人/无人）</li>
 *   <li>Temperature / Humidity / Lux → 阳台环境记录 + 环境检测设备的只读数值</li>
 *   <li>设备上下线通知 → device.online</li>
 * </ul>
 * 全部按"值变化才写库"节流：设备每 3 秒上报一次，不变就不刷库。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class HuaweiSyncService {

    private final HuaweiIoTProperties props;
    private final DeviceMapper deviceMapper;
    private final RoomMapper roomMapper;
    private final RoomEnvironmentMapper roomEnvironmentMapper;
    private final SystemConfigMapper systemConfigMapper;

    /** 有传感器的房间名（与 DeviceServiceImpl.ENV_ROOM_NAME 保持一致） */
    private static final String ENV_ROOM_NAME = "阳台";

    /** 系统配置键：全屋自动/手动模式 */
    public static final String CONFIG_KEY_MODE = "mode";

    /** NORMAL / ALARM 两种烟雾枚举对应的浓度展示值 */
    private static final int SMOKE_NORMAL = 6;
    private static final int SMOKE_ALARM = 80;

    /** 物模型属性名 → 本地设备类型（与 DeviceTypes 一一对应） */
    private static final Map<String, String> STATUS_PROPERTY = Map.of(
            "LightStatus", DeviceTypes.LIGHT,
            "MotorStatus", DeviceTypes.FAN,
            "ServoStatus", DeviceTypes.GATE,
            "BeepStatus", DeviceTypes.BEEP
    );

    /** 上次写库的 power 快照（类型 → "on"/"off"），值没变就不写库 */
    private final Map<String, String> lastPower = new ConcurrentHashMap<>();

    // ==================== 入口一：REST 轮询 ====================

    /** 扁平属性 Map（queryProperties 返回的结构）直接同步。 */
    public void syncProperties(Map<String, Object> properties) {
        syncDevicePower(properties);
        syncSmokeDevice(properties);
        syncPirDevice(properties);
        syncEnvironment(properties);
        syncMode(properties);
    }

    // ==================== 入口二：AMQP 推送 ====================

    /**
     * 处理 AMQP 推送报文。格式（华为云设备数据队列标准结构）：
     * <pre>
     * 属性上报：  {"resource":"property","event":"report",
     *              "notify_data":{"header":{"device_id":"..."},
     *                             "body":{"services":[{"service_id":"smart_home","properties":{...}}]}}}
     * 设备上下线：{"resource":"device.status","event":"status_changed",
     *              "notify_data":{"header":{"device_id":"..."},
     *                             "body":{"status":"ONLINE"/"OFFLINE",...}}}
     * </pre>
     * 只处理本设备（props.deviceId）的报文，其余忽略。任何解析异常都不会抛出
     * （推送是持续的，一条脏报文不能打断消费循环）。
     */
    public void handlePushMessage(String content) {
        try {
            JSONObject msg = JSONUtil.parseObj(content);
            String resource = msg.getStr("resource");
            String event = msg.getStr("event");
            JSONObject notify = msg.getJSONObject("notify_data");
            if (notify == null) {
                return;
            }
            JSONObject header = notify.getJSONObject("header");
            String deviceId = header == null ? null : header.getStr("device_id");
            boolean ours = deviceId != null && deviceId.equals(props.getDeviceId());
            if (!ours) {
                // 推送是通的但 device_id 对不上时，这里打一行便于排查（正常配好后不会再出现）
                log.warn("[华为云] 收到非本设备推送｜resource={} device_id={} 本机期望={}",
                        resource, deviceId, props.getDeviceId());
                return;     // 队列里可能有其他设备的报文（如 MQTTX 虚拟设备），过滤掉
            }

            // 属性上报的 resource 实测是 "device.property"（2026-11-20 消息跟踪详情核实），
            // 兼容 "property" 写法；状态变更的 resource 是 "device.status"
            boolean isPropertyReport = "report".equals(event)
                    && ("device.property".equals(resource) || "property".equals(resource));
            if (isPropertyReport) {
                JSONObject body = notify.getJSONObject("body");
                JSONArray services = body == null ? null : body.getJSONArray("services");
                if (services == null) {
                    return;
                }
                Map<String, Object> flat = new LinkedHashMap<>();
                for (Object o : services) {
                    JSONObject svc = (JSONObject) o;
                    JSONObject pr = svc.getJSONObject("properties");
                    if (pr != null) {
                        flat.putAll(pr);
                    }
                }
                log.info("[华为云] 收到属性上报｜{}", flat);
                syncDevicePower(flat);
                syncSmokeDevice(flat);
                syncPirDevice(flat);
                syncEnvironment(flat);
                syncMode(flat);

            } else if ("device.status".equals(resource)) {
                JSONObject body = notify.getJSONObject("body");
                if (body != null) {
                    boolean online = "ONLINE".equalsIgnoreCase(body.getStr("status"));
                    setAllOnline(online);
                    log.info("[华为云] 设备{}通知 → 本地设备全部标记{}",
                            online ? "上线" : "下线", online ? "在线" : "离线");
                }
            }
            // 其他 resource（message / event 等）不处理
        } catch (Exception e) {
            log.warn("[华为云] 推送报文处理异常：{}", e.getMessage());
        }
    }

    // ==================== 写库逻辑（两个入口共用） ====================

    /** 设备开关同步：值变化才写库；收到上报即视为在线。 */
    private void syncDevicePower(Map<String, Object> properties) {
        List<Device> devices = deviceMapper.selectList(null);
        for (Device dev : devices) {
            String matchKey = null;
            for (Map.Entry<String, String> e : STATUS_PROPERTY.entrySet()) {
                if (e.getValue().equals(dev.getType())) {
                    matchKey = e.getKey();
                    break;
                }
            }
            if (matchKey == null) {
                continue;   // 只读传感器在各自的同步方法里处理
            }
            Object statusVal = properties.get(matchKey);
            if (statusVal == null) {
                continue;
            }
            String power = "ON".equalsIgnoreCase(String.valueOf(statusVal)) ? "on" : "off";
            boolean powerChanged = !power.equals(lastPower.get(dev.getType()));
            boolean offline = dev.getOnline() == null || dev.getOnline() == 0;
            if (!powerChanged && !offline) {
                continue;   // 状态和在线标志都没变，不写库
            }

            if (powerChanged) {
                Map<String, Object> status = JSONUtil.parseObj(dev.getStatus());
                status.put("power", power);
                dev.setStatus(JSONUtil.toJsonStr(status));
                lastPower.put(dev.getType(), power);
                log.info("[华为云] 状态同步｜设备#{}-{}({}) {} → power={}",
                        dev.getId(), dev.getName(), dev.getType(), matchKey, power);
            }
            if (offline) {
                dev.setOnline(1);
            }
            deviceMapper.updateById(dev);
        }
    }

    /**
     * 烟雾传感器同步：SmokeStatus → 设备状态里的 smoke 展示值 + alarm 报警位。
     * 设备端上报格式（2026-11-20 与 Smart_Home_Demo 核对）：ON = 检测到烟雾（报警），
     * OFF = 正常；后端同时兼容 ALARM/NORMAL 两种枚举写法。
     */
    private void syncSmokeDevice(Map<String, Object> properties) {
        Object smoke = properties.get("SmokeStatus");
        if (smoke == null) {
            return;
        }
        String v = String.valueOf(smoke);
        boolean alarm = "ALARM".equalsIgnoreCase(v) || "ON".equalsIgnoreCase(v);
        int display = alarm ? SMOKE_ALARM : SMOKE_NORMAL;
        List<Device> sensors = deviceMapper.selectList(new LambdaQueryWrapper<Device>()
                .eq(Device::getType, DeviceTypes.SMOKE_SENSOR));
        for (Device dev : sensors) {
            Map<String, Object> status = JSONUtil.parseObj(dev.getStatus());
            int oldDisplay = status.get("smoke") instanceof Number ? ((Number) status.get("smoke")).intValue() : -1;
            int oldAlarm = status.get("alarm") instanceof Number ? ((Number) status.get("alarm")).intValue() : -1;
            if (oldDisplay == display && oldAlarm == (alarm ? 1 : 0)) {
                continue;       // 没变化不写库
            }
            status.put("smoke", display);
            status.put("alarm", alarm ? 1 : 0);
            dev.setStatus(JSONUtil.toJsonStr(status));
            deviceMapper.updateById(dev);
            if (alarm) {
                log.warn("[华为云] 烟雾告警｜SmokeStatus=ALARM → 设备#{}-{} 标记报警", dev.getId(), dev.getName());
            } else {
                log.info("[华为云] 状态同步｜设备#{}-{}(smoke_sensor) SmokeStatus=NORMAL",
                        dev.getId(), dev.getName());
            }
        }
    }

    /**
     * 人体感应同步：PIR_Status（ON/OFF）→ 人体感应设备的 present 字段
     * （on = 有人，off = 无人），前端卡片按这个显示。
     */
    private void syncPirDevice(Map<String, Object> properties) {
        Object pir = properties.get("PIR_Status");
        if (pir == null) {
            return;
        }
        String present = "ON".equalsIgnoreCase(String.valueOf(pir)) ? "on" : "off";
        List<Device> sensors = deviceMapper.selectList(new LambdaQueryWrapper<Device>()
                .eq(Device::getType, DeviceTypes.PIR_SENSOR));
        for (Device dev : sensors) {
            Map<String, Object> status = JSONUtil.parseObj(dev.getStatus());
            if (present.equals(status.get("present"))) {
                continue;
            }
            status.put("present", present);
            dev.setStatus(JSONUtil.toJsonStr(status));
            deviceMapper.updateById(dev);
            log.info("[华为云] 状态同步｜设备#{}-{}(pir_sensor) PIR_Status={} → present={}",
                    dev.getId(), dev.getName(), pir, present);
        }
    }

    /**
     * 环境数据同步：Temperature / Humidity / Lux 双写——
     * ① 阳台房间的 room_environment 记录（首页环境面板用）；
     * ② 环境检测设备的只读状态（设备卡片/详情页用）。
     * 硬件只有一套传感器，约定归属"阳台"房间。
     */
    private void syncEnvironment(Map<String, Object> properties) {
        Double temperature = numOf(properties.get("Temperature"), -20, 60);
        Integer humidity = intOf(properties.get("Humidity"), 0, 100);
        Double lux = numOf(properties.get("Lux"), 0, 65535);
        if (temperature == null && humidity == null && lux == null) {
            return;
        }

        // ① 阳台房间环境记录
        Room envRoom = roomMapper.selectOne(new LambdaQueryWrapper<Room>()
                .eq(Room::getName, ENV_ROOM_NAME).last("LIMIT 1"));
        if (envRoom != null) {
            RoomEnvironment env = roomEnvironmentMapper.selectOne(
                    new LambdaQueryWrapper<RoomEnvironment>().eq(RoomEnvironment::getRoomId, envRoom.getId()));
            if (env != null) {
                boolean changed = false;
                if (temperature != null && !temperature.equals(env.getTemperature())) {
                    env.setTemperature(temperature);
                    changed = true;
                }
                if (humidity != null && !humidity.equals(env.getHumidity())) {
                    env.setHumidity(humidity);
                    changed = true;
                }
                if (lux != null && !lux.equals(env.getLux())) {
                    env.setLux(lux);
                    changed = true;
                }
                if (changed) {
                    env.setUpdateTime(LocalDateTime.now());
                    roomEnvironmentMapper.updateById(env);
                    log.info("[华为云] 环境同步｜房间#{}-{} 温度{}℃ 湿度{}% 光照{}lx",
                            envRoom.getId(), envRoom.getName(),
                            env.getTemperature(), env.getHumidity(), env.getLux());
                }
            }
        }

        // ② 环境检测设备状态
        List<Device> envDevices = deviceMapper.selectList(new LambdaQueryWrapper<Device>()
                .eq(Device::getType, DeviceTypes.ENV_SENSOR));
        for (Device dev : envDevices) {
            Map<String, Object> status = JSONUtil.parseObj(dev.getStatus());
            boolean changed = false;
            Double oldTemp = numOf(status.get("temperature"), -20, 60);
            Integer oldHumidity = intOf(status.get("humidity"), 0, 100);
            Double oldLux = numOf(status.get("lux"), 0, 65535);
            if (temperature != null && !temperature.equals(oldTemp)) {
                status.put("temperature", temperature);
                changed = true;
            }
            if (humidity != null && !humidity.equals(oldHumidity)) {
                status.put("humidity", humidity);
                changed = true;
            }
            if (lux != null && !lux.equals(oldLux)) {
                status.put("lux", lux);
                changed = true;
            }
            if (changed) {
                dev.setStatus(JSONUtil.toJsonStr(status));
                deviceMapper.updateById(dev);
            }
        }
    }

    /**
     * 全屋模式同步：ModeStatus（AUTO/MANUAL）→ system_config 表的 mode 键。
     * 硬件只有一块板，自动模式是全屋开关而不是某个设备的属性。
     * App 在首页切换模式后，设备执行成功并上报，这里把库里的值对齐为真实状态。
     * 值没变不写库（设备每秒上报一次，不能每次都刷表）。
     */
    private void syncMode(Map<String, Object> properties) {
        Object mode = properties.get("ModeStatus");
        if (mode == null) {
            return;
        }
        boolean auto = "AUTO".equalsIgnoreCase(String.valueOf(mode));
        String value = auto ? "AUTO" : "MANUAL";
        SystemConfig cfg = systemConfigMapper.selectOne(new LambdaQueryWrapper<SystemConfig>()
                .eq(SystemConfig::getConfigKey, CONFIG_KEY_MODE));
        if (cfg == null) {
            cfg = new SystemConfig();
            cfg.setConfigKey(CONFIG_KEY_MODE);
            cfg.setConfigValue(value);
            systemConfigMapper.insert(cfg);
            log.info("[华为云] 模式同步｜{}（首次写入）", value);
        } else if (!value.equals(cfg.getConfigValue())) {
            cfg.setConfigValue(value);
            systemConfigMapper.updateById(cfg);
            log.info("[华为云] 模式同步｜设备切换为{}", auto ? "自动模式" : "手动模式");
        }
    }

    /** 全部设备统一标记在线 / 离线（本系统的设备对应一块硬件板子） */
    private void setAllOnline(boolean online) {
        List<Device> devices = deviceMapper.selectList(null);
        for (Device dev : devices) {
            if (dev.getOnline() == null || dev.getOnline() == (online ? 0 : 1)) {
                dev.setOnline(online ? 1 : 0);
                deviceMapper.updateById(dev);
            }
        }
    }

    // ==================== 数值安全转换 ====================

    /**
     * 取 Double 并做范围校验，非法/越界返回 null。
     * 兼容两种上报形式：JSON 数字（27.4）和字符串（"27.4"）——
     * 小熊派侧若把物模型属性定义为 string，平台推过来的就是字符串。
     */
    private Double numOf(Object o, double min, double max) {
        if (o == null) {
            return null;
        }
        double v;
        if (o instanceof Number) {
            v = ((Number) o).doubleValue();
        } else {
            try {
                v = Double.parseDouble(String.valueOf(o).trim());
            } catch (Exception e) {
                return null;
            }
        }
        return (v >= min && v <= max) ? v : null;
    }

    /** 取 Integer 并做范围校验，非法/越界返回 null（同样兼容字符串数字） */
    private Integer intOf(Object o, int min, int max) {
        Double d = numOf(o, min, max);
        return d == null ? null : (int) Math.round(d);
    }

}
