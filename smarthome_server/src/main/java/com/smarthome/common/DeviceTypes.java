package com.smarthome.common;

import java.util.Map;

/**
 * 设备类型字典：全部 7 种设备类型的"唯一事实来源"。
 *
 * <p>【2026-11-19 对齐硬件】设备清单按实训箱（Smart_Home_Demo）实际存在的设备收敛：
 * 可控设备 5 种（灯 / 风扇 / 自动门 / 蜂鸣器 / 烟雾传感器），
 * 只读传感器 2 种（环境检测 = 温湿度+光照，人体感应 = 红外 PIR）。
 * 此前的 17 种类型（空调/电视/冰箱等纯模拟设备）已删除。
 *
 * <p>状态字段约定（与硬件侧华为云物模型一一对应）：
 * <ul>
 *   <li>light      → Light_control / LightStatus：power on/off，亮度、色温为本地展示功能</li>
 *   <li>fan        → Motor_control / MotorStatus：power on/off</li>
 *   <li>gate       → Servo_control / ServoStatus：power on = 开门，off = 关门</li>
 *   <li>beep       → Beep_control / BeepStatus：power on = 鸣响，off = 静音</li>
 *   <li>smoke_sensor → SmokeStatus（NORMAL/ALARM 枚举）：只读展示</li>
 *   <li>pir_sensor → PIR_Status（ON/OFF）：只读展示，有人/无人</li>
 *   <li>env_sensor → Temperature / Humidity / Lux：只读展示</li>
 * </ul>
 * 新增类型 = 在这里加常量 + 默认状态 + 前端三处同步（Const.ets /
 * deviceTypeIcon() / AddDevicePage）。
 */
public final class DeviceTypes {

    private DeviceTypes() {
    }

    // ---- 可控设备（5 种）----
    public static final String LIGHT = "light";               // 灯：开关 / 亮度 / 色温
    public static final String FAN = "fan";                   // 风扇：开关
    public static final String GATE = "gate";                 // 舵机自动门：开门 / 关门
    public static final String BEEP = "beep";                 // 蜂鸣器：鸣响 / 静音
    public static final String SMOKE_SENSOR = "smoke_sensor"; // 烟雾传感器：状态跟随硬件上报

    // ---- 只读传感器（2 种，硬件直接上报，App 只看不动）----
    public static final String ENV_SENSOR = "env_sensor";     // 环境检测：温湿度 + 光照（阳台）
    public static final String PIR_SENSOR = "pir_sensor";     // 人体感应：有人 / 无人（卧室）

    /** 全部类型（types() 字典接口的顺序 = 这里数组的顺序） */
    public static final String[] ALL = {
            LIGHT, FAN, GATE, BEEP, SMOKE_SENSOR, ENV_SENSOR, PIR_SENSOR
    };

    /** 类型 → 中文名（与前端 deviceTypeName() 一致） */
    public static final Map<String, String> NAMES = Map.ofEntries(
            Map.entry(LIGHT, "灯"),
            Map.entry(FAN, "风扇"),
            Map.entry(GATE, "自动门"),
            Map.entry(BEEP, "蜂鸣器"),
            Map.entry(SMOKE_SENSOR, "烟雾传感器"),
            Map.entry(ENV_SENSOR, "环境检测"),
            Map.entry(PIR_SENSOR, "人体感应")
    );

    /**
     * 各类型新增时的默认状态 JSON。
     * timerOn / timerOff 是所有类型通用的"每日定时开/关"，空串 = 不定时（DeviceTimedTask 执行）。
     */
    public static final Map<String, String> DEFAULT_STATUS = Map.ofEntries(
            Map.entry(LIGHT,
                    "{\"power\":\"off\",\"brightness\":80,\"colorTemp\":4000,"
                            + "\"timerOn\":\"\",\"timerOff\":\"\"}"),
            Map.entry(FAN,
                    "{\"power\":\"off\",\"timerOn\":\"\",\"timerOff\":\"\"}"),
            Map.entry(GATE,
                    "{\"power\":\"off\",\"timerOn\":\"\",\"timerOff\":\"\"}"),
            Map.entry(BEEP,
                    "{\"power\":\"off\",\"timerOn\":\"\",\"timerOff\":\"\"}"),
            // 烟雾传感器：smoke 展示值与 alarm 位由硬件 SmokeStatus 同步（NORMAL=6 / ALARM=80）
            Map.entry(SMOKE_SENSOR,
                    "{\"power\":\"on\",\"smoke\":6,\"alarm\":0,\"battery\":100,"
                            + "\"timerOn\":\"\",\"timerOff\":\"\"}"),
            // 环境检测：三项只读数值由硬件上报同步，未上报前留空（App 显示 --）
            Map.entry(ENV_SENSOR, "{}"),
            // 人体感应：present 由硬件 PIR_Status 同步（on=有人 / off=无人）
            Map.entry(PIR_SENSOR,
                    "{\"present\":\"off\"}")
    );

    /**
     * 取某类型的默认状态；未登记的类型给"最小可用"兜底（power + 通用定时），
     * 保证字典和业务解耦 —— 就算忘了配默认状态，设备也能添加成功。
     */
    public static String defaultStatus(String type) {
        return DEFAULT_STATUS.getOrDefault(type,
                "{\"power\":\"off\",\"timerOn\":\"\",\"timerOff\":\"\"}");
    }

    /** 只读传感器（App 上没有开关可发）：env_sensor / pir_sensor / smoke_sensor 的数值都是上报的 */
    public static boolean isReadOnlySensor(String type) {
        return ENV_SENSOR.equals(type) || PIR_SENSOR.equals(type);
    }
}
