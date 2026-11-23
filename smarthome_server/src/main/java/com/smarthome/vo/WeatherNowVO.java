package com.smarthome.vo;

import lombok.Data;

/**
 * 实时天气 VO（GET /api/weather/now）—— 和风天气 v7/weather/now 的 now 节点原样透传。
 *
 * <p>【全部保留 String】和风天气返回的所有观测值都是字符串，
 * 前端按需展示、自己排版；后端不做数值转换，加字段零改动。
 *
 * <p>字段含义（前端 UI 依据）：
 * temp 实时温度℃ / feelsLike 体感℃ / text 天气现象 / icon 图标代码 /
 * windDir 风向 / windScale 风力等级 / windSpeed 风速km/h / wind360 风向角度 /
 * humidity 湿度% / precip 当前小时降水量mm / pressure 气压hPa /
 * vis 能见度km / cloud 云量% / dew 露点温度℃ / obsTime 观测时间
 */
@Data
public class WeatherNowVO {

    /** 数据更新时间（平台侧），如 2026-09-23T01:40+08:00 */
    private String updateTime;

    /** 实况观测时间 */
    private String obsTime;

    /** 实时温度（℃） */
    private String temp;

    /** 体感温度（℃） */
    private String feelsLike;

    /** 天气现象文字，如 晴 / 多云 / 雾 */
    private String text;

    /** 和风天气图标代码（前端可映射 emoji） */
    private String icon;

    /** 风向（如 北风） */
    private String windDir;

    /** 风向 360 度角度 */
    private String wind360;

    /** 风力等级（如 3） */
    private String windScale;

    /** 风速（km/h） */
    private String windSpeed;

    /** 相对湿度（%） */
    private String humidity;

    /** 当前小时累计降水量（mm） */
    private String precip;

    /** 大气压强（hPa） */
    private String pressure;

    /** 云量（%） */
    private String cloud;

    /** 露点温度（℃） */
    private String dew;

    /** 能见度（km） */
    private String vis;

    /** 本次查询的城市名（后端按 location 反查城市列表得到，方便前端直接显示） */
    private String cityName;

    /** 本次查询的 location id */
    private String location;
}
