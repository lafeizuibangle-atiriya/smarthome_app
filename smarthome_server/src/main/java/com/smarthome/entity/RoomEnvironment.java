package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 房间环境监测数据。
 * 【2026-11-19 对齐硬件】只保留硬件真实具备的三项：温度 / 湿度 / 光照。
 * 数据来源是华为云上报（HuaweiSyncService 写入），约定归属"阳台"房间；
 * 其他房间没有传感器，environment 接口返回 null 值，前端显示"暂无环境检测"。
 * 旧的 aqi / co2 / gas / smoke 列已废弃（建表里还留着，实体不再映射）。
 */
@Data
@TableName("room_environment")
public class RoomEnvironment {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long roomId;        // 一个房间一条（唯一索引）
    private Double temperature; // ℃（SHT30 上报）
    private Integer humidity;   // %（SHT30 上报）
    private Double lux;         // 光照强度 lx（BH1750 上报，0~65535）
    private LocalDateTime updateTime;
}
