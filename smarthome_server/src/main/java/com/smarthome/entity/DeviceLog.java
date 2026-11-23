package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 设备操作日志（对应表 device_log）—— 设备详情页的"操作记录"数据来源。
 * 插入时只填 deviceId / userId / action，id 与 createTime 交给数据库默认值。
 */
@Data
@TableName("device_log")
public class DeviceLog {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long deviceId;
    private Long userId;
    /** 动作描述，例：控制：{"power":"on"} */
    private String action;
    /** 数据库里是 DEFAULT CURRENT_TIMESTAMP，不传即为当前时间 */
    private LocalDateTime createTime;
}
