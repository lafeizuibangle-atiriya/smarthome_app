package com.smarthome.service.impl;

import cn.hutool.http.HttpUtil;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.smarthome.common.BizException;
import com.smarthome.service.WeatherService;
import com.smarthome.vo.WeatherAirVO;
import com.smarthome.vo.WeatherNowVO;
import com.smarthome.vo.WeatherWarningVO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 天气服务实现：HTTP 调和风天气（实况 / 空气质量 / 气象预警）+ 内存缓存。
 *
 * <p>【缓存 10 分钟】免费开发 KEY 有 QPS 和每日次数限制；
 * App 端每 60 分钟刷一次，后端再兜一层缓存，基本不会真实打到和风服务器。
 * 缓存用 ConcurrentHashMap（key = location），不需要 Redis（丢一行缓存无伤大雅）。
 */
@Slf4j
@Service
public class WeatherServiceImpl implements WeatherService {

    /** 和风天气接口地址（实况 / 空气 / 预警三个端点）与 KEY，都来自 application.yml */
    @Value("${qweather.api.url}")
    private String apiUrl;

    @Value("${qweather.api.air-url}")
    private String airUrl;

    @Value("${qweather.api.warning-url}")
    private String warningUrl;

    @Value("${qweather.api.key}")
    private String apiKey;

    @Value("${qweather.api.location}")
    private String defaultLocation;

    /** 缓存有效期 10 分钟 */
    private static final long CACHE_MS = 10 * 60 * 1000L;

    /**
     * 缓存条目：值 + 存入时间戳。
     * 【2026-11-23 改为 Object】空气质量/预警加入后一个缓存结构服务三种数据，取出来时各自强转。
     */
    private static class CacheEntry {
        final Object value;
        final long at;
        CacheEntry(Object value, long at) { this.value = value; this.at = at; }
    }

    /** 三类数据各自的缓存（key = location） */
    private final Map<String, CacheEntry> nowCache = new ConcurrentHashMap<>();
    private final Map<String, CacheEntry> airCache = new ConcurrentHashMap<>();
    private final Map<String, CacheEntry> warnCache = new ConcurrentHashMap<>();

    /**
     * 可切换城市固定清单（LinkedHashMap 保序；id 是和风城市 id）。
     * 排第一个的是默认城市（南昌）。
     */
    private static final Map<String, String> CITIES = new LinkedHashMap<>() {{
        put("101240101", "南昌");
        put("101010100", "北京");
        put("101020100", "上海");
        put("101030100", "天津");
        put("101040100", "重庆");
        put("101050101", "哈尔滨");
        put("101060101", "长春");
        put("101070101", "沈阳");
        put("101080101", "呼和浩特");
        put("101090101", "石家庄");
        put("101100101", "太原");
        put("101110101", "西安");
        put("101120201", "青岛");
        put("101130101", "乌鲁木齐");
        put("101140101", "拉萨");
        put("101150101", "西宁");
        put("101160101", "兰州");
        put("101170101", "银川");
        put("101180101", "郑州");
        put("101190101", "南京");
        put("101200101", "武汉");
        put("101210101", "杭州");
        put("101220101", "合肥");
        put("101230101", "福州");
        put("101250101", "长沙");
        put("101270101", "成都");
        put("101280101", "广州");
        put("101280601", "深圳");
        put("101290101", "昆明");
        put("101300101", "南宁");
        put("101310101", "海口");
        put("101320101", "中国香港");
        put("101330101", "中国澳门");
    }};

    @Override
    public WeatherNowVO now(String location) {
        final String loc = resolveLocation(location);

        // 1. 查缓存：10 分钟内直接返回，不打和风服务器
        CacheEntry hit = nowCache.get(loc);
        if (hit != null && System.currentTimeMillis() - hit.at < CACHE_MS) {
            return (WeatherNowVO) hit.value;
        }

        // 2. 真实请求 + 组装 VO
        JSONObject root = qweatherGet(apiUrl, loc, "实况天气");
        JSONObject now = root.getJSONObject("now");
        WeatherNowVO vo = new WeatherNowVO();
        vo.setUpdateTime(root.getStr("updateTime"));
        vo.setObsTime(now.getStr("obsTime"));
        vo.setTemp(now.getStr("temp"));
        vo.setFeelsLike(now.getStr("feelsLike"));
        vo.setText(now.getStr("text"));
        vo.setIcon(now.getStr("icon"));
        vo.setWindDir(now.getStr("windDir"));
        vo.setWind360(now.getStr("wind360"));
        vo.setWindScale(now.getStr("windScale"));
        vo.setWindSpeed(now.getStr("windSpeed"));
        vo.setHumidity(now.getStr("humidity"));
        vo.setPrecip(now.getStr("precip"));
        vo.setPressure(now.getStr("pressure"));
        vo.setCloud(now.getStr("cloud"));
        vo.setDew(now.getStr("dew"));
        vo.setVis(now.getStr("vis"));
        vo.setCityName(cityName(loc));
        vo.setLocation(loc);

        // 3. 入缓存
        nowCache.put(loc, new CacheEntry(vo, System.currentTimeMillis()));
        log.info("[天气] 实况查询成功：location={} {}℃ {}", loc, vo.getTemp(), vo.getText());
        return vo;
    }

    @Override
    public WeatherAirVO air(String location) {
        final String loc = resolveLocation(location);

        CacheEntry hit = airCache.get(loc);
        if (hit != null && System.currentTimeMillis() - hit.at < CACHE_MS) {
            return (WeatherAirVO) hit.value;
        }

        JSONObject root = qweatherGet(airUrl, loc, "空气质量");
        JSONObject now = root.getJSONObject("now");
        WeatherAirVO vo = new WeatherAirVO();
        vo.setUpdateTime(root.getStr("updateTime"));
        vo.setPubTime(now.getStr("pubTime"));
        vo.setAqi(now.getStr("aqi"));
        vo.setLevel(now.getStr("level"));
        vo.setCategory(now.getStr("category"));
        vo.setPrimary(now.getStr("primary"));
        vo.setPm10(now.getStr("pm10"));
        vo.setPm2p5(now.getStr("pm2p5"));
        vo.setNo2(now.getStr("no2"));
        vo.setSo2(now.getStr("so2"));
        vo.setCo(now.getStr("co"));
        vo.setO3(now.getStr("o3"));
        vo.setCityName(cityName(loc));
        vo.setLocation(loc);

        airCache.put(loc, new CacheEntry(vo, System.currentTimeMillis()));
        log.info("[天气] 空气质量查询成功：location={} AQI={} {}", loc, vo.getAqi(), vo.getCategory());
        return vo;
    }

    @Override
    public List<WeatherWarningVO> warnings(String location) {
        final String loc = resolveLocation(location);

        CacheEntry hit = warnCache.get(loc);
        if (hit != null && System.currentTimeMillis() - hit.at < CACHE_MS) {
            @SuppressWarnings("unchecked")
            List<WeatherWarningVO> cached = (List<WeatherWarningVO>) hit.value;
            return cached;
        }

        JSONObject root = qweatherGet(warningUrl, loc, "气象预警");
        List<WeatherWarningVO> list = new ArrayList<>();
        // 无预警时和风不返回 warning 字段（或返回空数组），都按空列表处理——这不是错误
        if (root.containsKey("warning")) {
            for (Object item : root.getJSONArray("warning")) {
                JSONObject w = (JSONObject) item;
                WeatherWarningVO vo = new WeatherWarningVO();
                vo.setId(w.getStr("id"));
                vo.setSender(w.getStr("sender"));
                vo.setPubTime(w.getStr("pubTime"));
                vo.setTitle(w.getStr("title"));
                vo.setStartTime(w.getStr("startTime"));
                vo.setEndTime(w.getStr("endTime"));
                vo.setLevel(w.getStr("level"));
                vo.setSeverity(w.getStr("severity"));
                vo.setSeverityColor(w.getStr("severityColor"));
                vo.setType(w.getStr("type"));
                vo.setTypeName(w.getStr("typeName"));
                vo.setText(w.getStr("text"));
                list.add(vo);
            }
        }

        warnCache.put(loc, new CacheEntry(list, System.currentTimeMillis()));
        log.info("[天气] 预警查询成功：location={} 条数={}", loc, list.size());
        return list;
    }

    @Override
    public List<Map<String, String>> cities() {
        // 每次现场组装（33 个条目的开销可以忽略），保序返回 [{id, name}]
        return CITIES.entrySet().stream()
                .map(e -> {
                    Map<String, String> m = new LinkedHashMap<>();
                    m.put("id", e.getKey());
                    m.put("name", e.getValue());
                    return m;
                })
                .toList();
    }

    // ========================= 内部工具 =========================

    /** location 空则用默认城市 */
    private String resolveLocation(String location) {
        return (location == null || location.isEmpty()) ? defaultLocation : location;
    }

    /** location → 城市名（清单里没有就显示"未知城市"） */
    private String cityName(String loc) {
        return CITIES.getOrDefault(loc, "未知城市");
    }

    /**
     * 请求和风天气并做统一校验，返回解析后的 JSON 根节点。
     * 三个端点（实况/空气/预警）共用：HTTP 层异常和业务错误码（如 402 次数用尽）
     * 都包装成 BizException，Controller 层不用重复写。
     */
    private JSONObject qweatherGet(String url, String loc, String apiName) {
        String body;
        try {
            body = HttpUtil.get(url + "?location=" + loc + "&key=" + apiKey + "&lang=zh", 10_000);
        } catch (Exception e) {
            log.error("[天气] 请求和风{}失败：location={} 原因={}", apiName, loc, e.getMessage());
            throw new BizException("天气服务暂时不可用，请稍后重试");
        }
        JSONObject root = JSONUtil.parseObj(body);
        if (!"200".equals(root.getStr("code", ""))) {
            log.error("[天气] 和风{}返回错误：location={} code={}", apiName, loc, root.getStr("code"));
            throw new BizException("天气查询失败（和风错误码 " + root.getStr("code", "?") + "）");
        }
        return root;
    }
}
