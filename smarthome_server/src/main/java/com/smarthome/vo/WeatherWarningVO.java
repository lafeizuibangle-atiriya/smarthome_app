package com.smarthome.vo;

import lombok.Data;

/**
 * 气象预警 VO（GET /api/weather/warning 返回列表的元素）——
 * 和风 v7/warning/now 的 warning 节点透传（2026-11-23 新增）。
 */
@Data
public class WeatherWarningVO {

    /** 预警 id */
    private String id;

    /** 发布单位（如 南昌市气象台） */
    private String sender;

    /** 发布时间 */
    private String pubTime;

    /** 预警标题（完整一句话，可直接展示） */
    private String title;

    /** 预警开始时间 */
    private String startTime;

    /** 预警结束时间 */
    private String endTime;

    /** 预警等级（中文：蓝色/黄色/橙色/红色） */
    private String level;

    /** 严重程度（英文：Minor/Moderate/Severe/Extreme） */
    private String severity;

    /** 严重程度对应颜色（Yellow/Orange/Red/Blue），前端可做配色 */
    private String severityColor;

    /** 预警类型代码 */
    private String type;

    /** 预警类型名称（如 大雾 / 暴雨 / 高温） */
    private String typeName;

    /** 预警详细内容 */
    private String text;
}
