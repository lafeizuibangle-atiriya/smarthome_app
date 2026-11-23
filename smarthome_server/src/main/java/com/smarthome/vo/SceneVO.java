package com.smarthome.vo;

import lombok.Data;

import java.util.List;
import java.util.Map;

/** 场景出参。详情接口额外带 actions 动作列表。 */
@Data
public class SceneVO {
    private Long id;
    private String name;
    private String icon;
    private String description;  // 场景说明（预设模式卡片展示，2026-09-29 新增）
    private String triggerType;  // MANUAL / TIMER
    private String cronExpr;     // "HH:mm"
    private Integer enabled;     // 1 启用 / 0 停用
    private List<Map<String, Object>> actions; // 详情接口带：[{deviceId, action:{...}}]
}
