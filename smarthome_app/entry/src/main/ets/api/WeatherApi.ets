// api/WeatherApi.ets —— 天气接口（后端代理和风天气，KEY 不落前端）
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { WeatherNow, WeatherCity } from '../model/Weather'

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
}
