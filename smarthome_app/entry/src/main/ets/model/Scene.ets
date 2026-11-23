// model/Scene.ets —— 数据模型：与后端 VO 字段一一对应（手册 5.3）
export interface SceneActionItem {
  deviceId: number
  deviceName?: string
  action: string          // JSON 字符串，如 {"power":"on"}
}

export interface Scene {
  id: number
  name: string
  icon?: string
  description?: string    // 场景说明（预设模式卡片展示，2026-09-29 新增）
  triggerType: string     // 'MANUAL' 手动 | 'TIMER' 定时自动化
  cronExpr?: string
  enabled: number         // 1 启用 0 停用
  actions?: SceneActionItem[]
}
