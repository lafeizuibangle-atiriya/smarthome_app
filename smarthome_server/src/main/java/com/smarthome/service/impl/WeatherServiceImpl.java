package com.smarthome.service.impl;

import cn.hutool.http.HttpUtil;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.smarthome.common.BizException;
import com.smarthome.service.WeatherService;
import com.smarthome.vo.WeatherNowVO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 天气服务实现：HTTP 调和风天气 v7/weather/now + 内存缓存。
 *
 * <p>【缓存 10 分钟】免费开发 KEY 有 QPS 和每日次数限制；
 * App 端每 60 分钟刷一次，后端再兜一层缓存，基本不会真实打到和风服务器。
 * 缓存用 ConcurrentHashMap（key = location），不需要 Redis（丢一行缓存无伤大雅）。
 */
@Slf4j
@Service
public class WeatherServiceImpl implements WeatherService {

    /** 和风天气接口地址 / KEY / 默认城市，都来自 application.yml */
    @Value("${qweather.api.url}")
    private String apiUrl;

    @Value("${qweather.api.key}")
    private String apiKey;

    @Value("${qweather.api.location}")
    private String defaultLocation;

    /** 缓存有效期 10 分钟 */
    private static final long CACHE_MS = 10 * 60 * 1000L;

    /** location → 缓存条目（值 + 存入时间戳） */
    private final Map<String, CacheEntry> cache = new ConcurrentHashMap<>();

    /** 缓存条目：只有 VO + 时间戳两个字段，private 内部类够了 */
    private static class CacheEntry {
        final WeatherNowVO vo;
        final long at;
        CacheEntry(WeatherNowVO vo, long at) { this.vo = vo; this.at = at; }
    }

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
        final String loc = (location == null || location.isEmpty()) ? defaultLocation : location;
        final String cityName = CITIES.getOrDefault(loc, "未知城市");

        // 1. 查缓存：10 分钟内直接返回，不打和风服务器
        CacheEntry hit = cache.get(loc);
        if (hit != null && System.currentTimeMillis() - hit.at < CACHE_MS) {
            log.info("[天气] 命中缓存：location={} city={}", loc, cityName);
            return hit.vo;
        }

        // 2. 真实请求和风天气（Hutool HttpUtil，UTF-8 解码）
        String url = apiUrl + "?location=" + loc + "&key=" + apiKey
                + "&lang=zh";
        String body;
        try {
            body = HttpUtil.get(url, 10_000);
        } catch (Exception e) {
            log.error("[天气] 请求和风天气失败：location={} 原因={}", loc, e.getMessage());
            throw new BizException("天气服务暂时不可用，请稍后重试");
        }

        JSONObject root = JSONUtil.parseObj(body);
        if (!"200".equals(root.getStr("code", ""))) {
            // 和风的错误码在业务 code 里（HTTP 层可能仍是 200），如 402 = 次数用尽
            log.error("[天气] 和风返回错误：location={} code={}", loc, root.getStr("code"));
            throw new BizException("天气查询失败（和风错误码 " + root.getStr("code", "?") + "）");
        }

        // 3. now 节点 → VO（字段名与和风完全一致，直接拷贝）
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
        vo.setCityName(cityName);
        vo.setLocation(loc);

        // 4. 入缓存
        cache.put(loc, new CacheEntry(vo, System.currentTimeMillis()));
        log.info("[天气] 查询成功：location={} city={} {}℃ {}",
                loc, cityName, vo.getTemp(), vo.getText());
        return vo;
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
}
