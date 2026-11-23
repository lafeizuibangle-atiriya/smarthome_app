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
