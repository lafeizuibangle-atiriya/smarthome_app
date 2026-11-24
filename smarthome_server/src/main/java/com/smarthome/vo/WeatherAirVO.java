package com.smarthome.vo;

import lombok.Data;

/**
 * 空气质量 VO（GET /api/weather/air）—— 和风 v7/air/now 的 now 节点透传（2026-11-23 新增）。
 * 全部保留 String，口径同 WeatherNowVO：后端不转数值，前端按需展示。
 */
@Data
public class WeatherAirVO {

    /** 数据更新时间（平台侧） */
    private String updateTime;

    /** 空气质量数据发布时间 */
    private String pubTime;

    /** AQI 指数（和风默认标准，数值越小越好） */
    private String aqi;

    /** AQI 等级（1-6） */
    private String level;

    /** 空气质量类别文字：优 / 良 / 轻度污染 ... */
    private String category;

    /** 首要污染物（优/良时为 NA） */
    private String primary;

    /** PM10 浓度（μg/m³） */
    private String pm10;

    /** PM2.5 浓度（μg/m³） */
    private String pm2p5;

    /** 二氧化氮浓度 */
    private String no2;

    /** 二氧化硫浓度 */
    private String so2;

    /** 一氧化碳浓度 */
    private String co;

    /** 臭氧浓度 */
    private String o3;

    /** 本次查询的城市名（后端按 location 反查） */
    private String cityName;

    /** 本次查询的 location id */
    private String location;
}
