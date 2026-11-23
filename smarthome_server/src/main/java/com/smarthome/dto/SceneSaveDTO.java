package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.util.List;
import java.util.Map;

/**
 * 场景保存入参（POST /api/scene 新建、PUT /api/scene 修改共用）。
 * actions 格式：[{ "deviceId": 1, "action": { "power": "off", "brightness": 20 } }]
 */
@Data
public class SceneSaveDTO {

    private Long id;             // 修改时带

    @NotBlank(message = "场景名不能为空")
    @Size(max = 20, message = "场景名最长 20 个字符")
    private String name;

    private String icon;

    @Size(max = 50, message = "场景说明最长 50 个字符")
    private String description;  // 场景说明（预设模式展示，2026-09-29 新增）

    /** MANUAL 手动 / TIMER 定时 */
    @Pattern(regexp = "^(MANUAL|TIMER)$", message = "触发方式只支持 MANUAL 或 TIMER")
    private String triggerType;

    /** 定时场景的时间 "HH:mm"；手动场景为空。正则同时校验 0-23 时 0-59 分 */
    @Pattern(regexp = "^$|^([01]\\d|2[0-3]):[0-5]\\d$", message = "定时时间格式应为 HH:mm")
    private String cronExpr;     // "HH:mm"

    private Integer enabled;     // 1 / 0

    private List<Map<String, Object>> actions;
}
