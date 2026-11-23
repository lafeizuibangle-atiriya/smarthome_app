package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 系统级配置（键值对）。
 * 【2026-11-20 新增】目前只存一项：mode（AUTO / MANUAL）——
 * 硬件只有一块板，"自动模式"是全屋开关而不是某个设备的属性，
 * 所以单独放一张系统配置表，设备上下行都围绕它同步。
 */
@Data
@TableName("system_config")
public class SystemConfig {
    @TableId(type = IdType.INPUT)
    private String configKey;       // 如 mode
    private String configValue;     // 如 AUTO / MANUAL
}
