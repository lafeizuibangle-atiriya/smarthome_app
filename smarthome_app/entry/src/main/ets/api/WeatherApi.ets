// api/WeatherApi.ets —— 天气接口（后端代理和风天气，KEY 不落前端）
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { WeatherNow, WeatherCity, WeatherAir, WeatherWarning } from '../model/Weather'

export class WeatherApi {
  /** 实时天气；location 空则后端用默认城市（南昌 101240101） */
  static now(location: string): Promise<ApiResponse<WeatherNow>> {
    if (location.length === 0) {
      return HttpClient.get<WeatherNow>('/api/weather/now')
    }
    return HttpClient.get<WeatherNow>(`/api/weather/now?location=${location}`)
  }

  /** 可切换城市清单（第一个是默认城市） */
  static cities(): Promise<ApiResponse<WeatherCity[]>> {
    return HttpClient.get<WeatherCity[]>('/api/weather/cities')
  }

  /** 空气质量 AQI（2026-11-23 新增） */
  static air(location: string): Promise<ApiResponse<WeatherAir>> {
    if (location.length === 0) {
      return HttpClient.get<WeatherAir>('/api/weather/air')
    }
    return HttpClient.get<WeatherAir>(`/api/weather/air?location=${location}`)
  }

  /** 当前生效的气象预警列表（2026-11-23 新增，无预警返回空数组） */
  static warning(location: string): Promise<ApiResponse<WeatherWarning[]>> {
    if (location.length === 0) {
      return HttpClient.get<WeatherWarning[]>('/api/weather/warning')
    }
    return HttpClient.get<WeatherWarning[]>(`/api/weather/warning?location=${location}`)
  }
}
