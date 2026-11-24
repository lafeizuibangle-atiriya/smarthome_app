package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.service.WeatherService;
import com.smarthome.vo.WeatherAirVO;
import com.smarthome.vo.WeatherNowVO;
import com.smarthome.vo.WeatherWarningVO;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 天气模块控制层（和风天气代理）。
 *
 * <p>端点：
 * <ul>
 *   <li>GET /api/weather/now?location=xxx   实时天气（location 空则用默认城市南昌）</li>
 *   <li>GET /api/weather/cities             可切换的城市清单</li>
 * </ul>
 *
 * <p>需要登录才能访问（不在 WebConfig 白名单里）—— 天气面板在首页里，
 * 登录后才看得到，跟设备/环境接口同一鉴权口径。
 */
@RestController
@RequestMapping("/api/weather")
@RequiredArgsConstructor
public class WeatherController {

    private final WeatherService weatherService;

    /** 实时天气：location 可空（默认南昌 101240101） */
    @GetMapping("/now")
    public Result<WeatherNowVO> now(@RequestParam(required = false) String location) {
        return Result.ok(weatherService.now(location));
    }

    /** 可切换城市清单（[{id, name}]，保序，第一个是默认城市） */
    @GetMapping("/cities")
    public Result<List<Map<String, String>>> cities() {
        return Result.ok(weatherService.cities());
    }

    /** 空气质量 AQI（2026-11-23 新增）：location 可空（默认南昌） */
    @GetMapping("/air")
    public Result<WeatherAirVO> air(@RequestParam(required = false) String location) {
        return Result.ok(weatherService.air(location));
    }

    /** 当前生效的气象预警列表（2026-11-23 新增），无预警返回空数组 */
    @GetMapping("/warning")
    public Result<List<WeatherWarningVO>> warning(@RequestParam(required = false) String location) {
        return Result.ok(weatherService.warnings(location));
    }
}
