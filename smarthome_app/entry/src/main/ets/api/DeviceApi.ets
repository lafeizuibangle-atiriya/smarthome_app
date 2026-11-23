// api/DeviceApi.ets —— 【铁律】所有 URL 只允许出现在 api/ 目录；页面禁止直接调 HttpClient（总方案 7.7）
// URL 一览见《03_接口文档.md》四。请求体必须先声明 interface（手册 5.0 ①）。
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { Device, Room, HomeOverview, RoomEnv, DeviceAction, DeviceLogItem, ModeAction } from '../model/Device'

/** 新增房间入参（对应后端 RoomDTO） */
export interface RoomParam {
  id?: number
  name: string
}

/** 添加设备入参（对应后端 DeviceAddDTO，模拟配网） */
export interface DeviceAddParam {
  roomId: number
  name: string
  type: string
}

/** 重命名设备入参（PUT /api/device，body 带 id） */
export interface DeviceRenameParam {
  id: number
  name: string
}

export class DeviceApi {
  /** 首页总览：一次拿全家庭 + 房间 + 设备 + 每个房间的环境数据 */
  static overview(): Promise<ApiResponse<HomeOverview>> {
    return HttpClient.get<HomeOverview>('/api/home/overview')
  }

  /** 全屋自动/手动模式切换（2026-11-20 新增）：返回切换后的模式字符串 */
  static setMode(mode: string): Promise<ApiResponse<string>> {
    const body: ModeAction = { mode: mode }
    return HttpClient.post<string>('/api/home/mode', body)
  }

  // ---------- 房间 ----------

  static roomList(): Promise<ApiResponse<Room[]>> {
    return HttpClient.get<Room[]>('/api/room/list')
  }

  static addRoom(name: string): Promise<ApiResponse<void>> {
    const body: RoomParam = { name: name }
    return HttpClient.post<void>('/api/room', body)
  }

  static renameRoom(roomId: number, name: string): Promise<ApiResponse<void>> {
    const body: RoomParam = { id: roomId, name: name }
    return HttpClient.put<void>('/api/room', body)
  }

  static removeRoom(roomId: number): Promise<ApiResponse<void>> {
    return HttpClient.delete<void>(`/api/room/${roomId}`)
  }

  // ---------- 设备 ----------

  static deviceList(roomId: number): Promise<ApiResponse<Device[]>> {
    return HttpClient.get<Device[]>(`/api/device/list?roomId=${roomId}`)
  }

  static deviceDetail(deviceId: number): Promise<ApiResponse<Device>> {
    return HttpClient.get<Device>(`/api/device/${deviceId}`)
  }

  /** 控制设备：必须用 DeviceAction，不能传裸字面量（手册 5.0 ①） */
  static control(deviceId: number, action: DeviceAction): Promise<ApiResponse<Device>> {
    return HttpClient.post<Device>(`/api/device/${deviceId}/control`, action)
  }

  static addDevice(roomId: number, name: string, type: string): Promise<ApiResponse<void>> {
    const body: DeviceAddParam = { roomId: roomId, name: name, type: type }
    return HttpClient.post<void>('/api/device', body)
  }

  static renameDevice(deviceId: number, name: string): Promise<ApiResponse<void>> {
    const body: DeviceRenameParam = { id: deviceId, name: name }
    return HttpClient.put<void>('/api/device', body)
  }

  static removeDevice(deviceId: number): Promise<ApiResponse<void>> {
    return HttpClient.delete<void>(`/api/device/${deviceId}`)
  }

  /** 设备类型字典（5 种，与前端 Const 保持一致） */
  static deviceTypes(): Promise<ApiResponse<string[]>> {
    return HttpClient.get<string[]>('/api/device/types')
  }

  /** 设备操作记录（详情页底部展示） */
  static deviceLogs(deviceId: number): Promise<ApiResponse<DeviceLogItem[]>> {
    return HttpClient.get<DeviceLogItem[]>(`/api/device/${deviceId}/logs`)
  }

  // ---------- 环境监测（2026-09 新增）----------

  /** 查单个房间的环境监测数据 */
  static environment(roomId: number): Promise<ApiResponse<RoomEnv>> {
    return HttpClient.get<RoomEnv>(`/api/room/${roomId}/environment`)
  }

  /** 环境指标字典（key/name/unit） */
  static envMetrics(): Promise<ApiResponse<Record<string, string>[]>> {
    return HttpClient.get<Record<string, string>[]>('/api/environment/metrics')
  }
}
