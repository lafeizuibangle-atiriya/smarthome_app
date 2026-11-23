// model/Device.ets —— 数据模型：与后端 VO 字段一一对应（手册 5.1，口径以《03_接口文档.md》四为准）
// 【2026-11-19 对齐硬件】7 种设备：可控 5 种 light/fan/gate/beep/smoke_sensor +
// 只读 2 种 env_sensor（温湿度光照）/ pir_sensor（人体感应）。

/** 设备动态属性：不同设备只用到其中几个字段，所以都用可选属性 */
export interface DeviceStatus {
  power?: string          // 'on' | 'off'（可控设备的开关都是 power；gate on = 开门）
  brightness?: number     // 灯亮度 1~100
  colorTemp?: number      // 灯色温：仅 2700 暖光 / 4000 自然 / 6500 冷白（后端白名单）
  // ---- 通用定时 ----
  timerOn?: string        // 每日定时开机 'HH:mm'，空串=不定时（后端 DeviceTimedTask 执行）
  timerOff?: string       // 每日定时关机 'HH:mm'，空串=不定时
  // ---- 烟雾传感器 smoke_sensor（只读，硬件 SmokeStatus 同步）----
  smoke?: number          // 展示值 ppm（NORMAL=6 / ALARM=80）
  alarm?: number          // 1 = 硬件报告烟雾报警
  battery?: number        // 电量 %（**只读**：设备上报）
  // ---- 环境检测 env_sensor（只读，硬件 SHT30/BH1750 上报）----
  temperature?: number    // ℃
  humidity?: number       // %
  lux?: number            // 光照强度 lx
  // ---- 人体感应 pir_sensor（只读，硬件 PIR_Status 同步）----
  present?: string        // 'on' 有人 | 'off' 无人
}

/**
 * 控制设备的**动作体**（对应后端 control(deviceId, action)）。
 * ⚠️ 必须单独声明这个 interface，不能把 { power: 'on' } 直接写进调用参数 ——
 *    ArkTS 严格模式禁止裸对象字面量（手册 5.0 ①），会直接编译失败。
 * ⚠️ 只读字段（smoke / battery / temperature / humidity / lux / present）不要放进动作体：
 *    后端 sanitizeAction 会直接丢弃并打警告日志。
 */
export interface DeviceAction {
  power?: string          // 'on' | 'off'（灯/风扇/自动门/蜂鸣器通用）
  brightness?: number     // 灯：1~100
  colorTemp?: number      // 灯：2700 / 4000 / 6500（暖光 / 自然 / 冷白）
  timerOn?: string        // 每日定时开机 "HH:mm"，空串=取消（后端 DeviceTimedTask 执行）
  timerOff?: string       // 每日定时关机 "HH:mm"，空串=取消
}

// ⚠️ 环境温度/湿度/光照是"房间的环境属性"，由 room_environment 表维护，
// 数据来自华为云上报，对应下面的 RoomEnv。

export interface Device {
  id: number
  roomId: number
  name: string
  type: string            // 7 种，见 DeviceStatus 注释（与硬件侧设备一一对应）
  status: DeviceStatus
  online: number          // 1 在线 0 离线
  createTime?: string
}

export interface Room {
  id: number
  name: string
}

/**
 * 房间环境监测数据（对应后端 RoomEnvironmentVO）。
 * 【2026-11-19 对齐硬件】只有温度/湿度/光照三项；数值来自硬件上报。
 * 只有阳台有传感器：其他房间三项为 null，前端显示"暂无环境检测"。
 */
export interface RoomEnv {
  roomId: number
  roomName: string
  temperature: number | null    // ℃；null = 该房间无传感器
  temperatureLevel: string      // 偏冷 / 舒适 / 偏热
  humidity: number | null       // %
  humidityLevel: string         // 干燥 / 舒适 / 潮湿
  lux: number | null            // 光照强度 lx
  alarmCount: number            // 兼容字段，恒为 0
  updateTime: string            // 空 = 无传感器
}

/** 全屋模式切换动作体（对应后端 POST /api/home/mode） */
export interface ModeAction {
  mode: string            // 'AUTO' | 'MANUAL'
}

/** 首页总览接口的返回结构 */
export interface HomeOverview {
  homeName: string
  rooms: Room[]
  devices: Device[]
  environments: RoomEnv[]     // 与 rooms 等长同序，下标一一对应
  alarmCount: number          // 全屋告警合计（恒为 0，告警走烟雾传感器卡片）
  mode: string                // 全屋模式：'AUTO' 自动 / 'MANUAL' 手动（硬件 ModeStatus 同步）
}

/** 设备操作记录（对应后端 DeviceLog，GET /api/device/{id}/logs） */
export interface DeviceLogItem {
  id: number
  deviceId: number
  userId: number
  action: string
  createTime: string
}
