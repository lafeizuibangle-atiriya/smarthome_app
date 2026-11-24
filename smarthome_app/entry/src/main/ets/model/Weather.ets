// model/Weather.ets —— 天气面板数据模型（对应后端 WeatherNowVO / 城市清单）
//
// 【全部保留 string】和风天气返回的所有观测值都是字符串，
// 后端原样透传，前端按需展示（避免二次转换丢失精度/口径）。

/** 实时天气（GET /api/weather/now）—— 字段含义见 WeatherPanel 的指标格 */
export interface WeatherNow {
  updateTime: string       // 平台数据更新时间
  obsTime: string          // 实况观测时间
  temp: string             // 实时温度（℃）
  feelsLike: string        // 体感温度（℃）
  text: string             // 天气现象：晴 / 多云 / 雾 ...
  icon: string             // 和风天气图标代码
  windDir: string          // 风向（如 北风）
  wind360: string          // 风向角度
  windScale: string        // 风力等级
  windSpeed: string        // 风速（km/h）
  humidity: string         // 相对湿度（%）
  precip: string           // 当前小时降水量（mm）
  pressure: string         // 大气压强（hPa）
  cloud: string            // 云量（%）
  dew: string              // 露点温度（℃）
  vis: string              // 能见度（km）
  cityName: string         // 城市名（后端按 location 反查）
  location: string         // 城市 id
}

/** 可切换城市（GET /api/weather/cities，[{id, name}]） */
export interface WeatherCity {
  id: string
  name: string
}

/** 空气质量（GET /api/weather/air，2026-11-23 新增，后端透传和风 v7/air/now） */
export interface WeatherAir {
  updateTime: string       // 平台数据更新时间
  pubTime: string          // 空气质量数据发布时间
  aqi: string              // AQI 指数（越小越好）
  level: string            // AQI 等级（1-6）
  category: string         // 类别文字：优 / 良 / 轻度污染 ...
  primary: string          // 首要污染物（优/良时为 NA）
  pm10: string             // PM10（μg/m³）
  pm2p5: string            // PM2.5（μg/m³）
  no2: string              // 二氧化氮
  so2: string              // 二氧化硫
  co: string               // 一氧化碳
  o3: string               // 臭氧
  cityName: string         // 城市名（后端反查）
  location: string         // 城市 id
}

/** 气象预警（GET /api/weather/warning，后端透传和风 v7/warning/now） */
export interface WeatherWarning {
  id: string               // 预警 id
  sender: string           // 发布单位（如 南昌市气象台）
  pubTime: string          // 发布时间
  title: string            // 预警标题（完整一句话，可直接展示）
  startTime: string        // 开始时间
  endTime: string          // 结束时间
  level: string            // 等级（蓝色/黄色/橙色/红色）
  severity: string         // 严重程度（英文）
  severityColor: string    // 严重程度颜色（Yellow/Orange/Red/Blue）
  type: string             // 类型代码
  typeName: string         // 类型名称（大雾/暴雨/高温...）
  text: string             // 详细内容
}
