package com.smarthome.service;

import com.smarthome.vo.WeatherAirVO;
import com.smarthome.vo.WeatherNowVO;
import com.smarthome.vo.WeatherWarningVO;

import java.util.List;
import java.util.Map;

/**
 * 天气服务（和风天气代理）。
 *
 * <p>【为什么后端代理而不让 App 直连和风】
 * <ul>
 *   <li>KEY 只放后端一处，不随 App 安装包到处跑；</li>
 *   <li>后端做 10 分钟内存缓存，多家 App 同时刷也不会撞免费 KEY 的 QPS 上限；</li>
 *   <li>统一走自家的 Result 包裹 + 三层架构，前端与其他接口用法一致。</li>
 * </ul>
 */
public interface WeatherService {

    /**
     * 查实时天气（10 分钟缓存）。
     *
     * @param location 和风城市 id，空则用默认城市（application.yml qweather.api.location）
     */
    WeatherNowVO now(String location);

    /**
     * 查空气质量 AQI（10 分钟缓存，2026-11-23 新增）。
     *
     * @param location 和风城市 id，空则用默认城市
     */
    WeatherAirVO air(String location);

    /**
     * 查当前生效的气象预警列表（10 分钟缓存，2026-11-23 新增）。
     * 无预警时返回空列表（不是错误）。
     */
    List<WeatherWarningVO> warnings(String location);

    /**
     * 可切换的城市列表（id + 名称，固定清单内置在后端）。
     */
    List<Map<String, String>> cities();
}
