// api/SceneApi.ets —— 【铁律】所有 URL 只允许出现在 api/ 目录；页面禁止直接调 HttpClient（总方案 7.7）
// URL 一览见《03_接口文档.md》五。
import { HttpClient, ApiResponse } from '../common/HttpClient'
import { Scene, SceneActionItem } from '../model/Scene'

/** 启停自动化入参（PUT /api/scene/{id}/toggle） */
export interface SceneToggleParam {
  enabled: number
}

/** 新建/修改场景入参（对应后端 SceneSaveDTO） */
export interface SceneSaveParam {
  id?: number
  name: string
  icon?: string
  triggerType: string        // 'MANUAL' | 'TIMER'
  cronExpr?: string          // 定时自动化存 'HH:mm'
  actions: SceneActionParam[]
}

/** 场景动作参数（禁止裸字面量，手册 5.0 ①） */
export interface SceneActionParam {
  deviceId: number
  action: string             // JSON 字符串，如 {"power":"on"}
}

export class SceneApi {
  /** 场景列表（MANUAL 手动 / TIMER 自动化） */
  static list(triggerType: string): Promise<ApiResponse<Scene[]>> {
    return HttpClient.get<Scene[]>(`/api/scene/list?type=${triggerType}`)
  }

  static detail(sceneId: number): Promise<ApiResponse<Scene>> {
    return HttpClient.get<Scene>(`/api/scene/${sceneId}`)
  }

  static save(param: SceneSaveParam): Promise<ApiResponse<void>> {
    return HttpClient.post<void>('/api/scene', param)
  }

  static update(param: SceneSaveParam): Promise<ApiResponse<void>> {
    return HttpClient.put<void>('/api/scene', param)
  }

  static remove(sceneId: number): Promise<ApiResponse<void>> {
    return HttpClient.delete<void>(`/api/scene/${sceneId}`)
  }

  /** 一键执行场景 */
  static run(sceneId: number): Promise<ApiResponse<void>> {
    return HttpClient.post<void>(`/api/scene/${sceneId}/run`)
  }

  /** 启停自动化（定时任务只执行 enabled=1 的场景） */
  static toggle(sceneId: number, enabled: number): Promise<ApiResponse<void>> {
    const body: SceneToggleParam = { enabled: enabled }
    return HttpClient.put<void>(`/api/scene/${sceneId}/toggle`, body)
  }
}
