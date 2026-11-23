package com.smarthome.vo;

import lombok.Data;

/**
 * 环境监测出参。
 * 【2026-11-19 对齐硬件】只保留硬件真实具备的三项：温度 / 湿度 / 光照。
 * 没有传感器的房间三项为 null，前端显示"暂无环境检测"。
 * alarmCount 保留字段兼容旧前端，恒为 0（真实告警走烟雾传感器设备卡片）。
 */
@Data
public class RoomEnvironmentVO {
    private Long roomId;
    private String roomName;

    private Double temperature;       private String temperatureLevel;  // 偏冷/舒适/偏热；null=无传感器
    private Integer humidity;         private String humidityLevel;     // 干燥/舒适/潮湿；null=无传感器
    private Double lux;               // 光照强度 lx；null=无传感器

    private Integer alarmCount;       // 兼容字段，恒为 0
    private String updateTime;        // 2026-11-19 15:00:00；null=无传感器
}
