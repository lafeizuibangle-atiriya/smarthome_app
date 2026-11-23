package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 场景/自动化表 scene。
 * triggerType: MANUAL 手动 / TIMER 定时；cronExpr 存 "HH:mm" 字符串。
 */
@Data
@TableName("scene")
public class Scene {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String name;
    private String icon;
    private String description; // 场景说明（前端预设模式卡片展示，2026-09-29 新增）
    private String triggerType; // MANUAL / TIMER
    private String cronExpr;    // "HH:mm"
    private Integer enabled;    // 1 启用 / 0 停用
}
