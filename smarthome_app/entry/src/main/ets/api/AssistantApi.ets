// api/AssistantApi.ets —— 智能助手接口（2026-11-23 新增，对应后端 AssistantController）
// 【铁律】URL 只出现在 api/ 目录；大模型回答慢，走 postLong（30 秒超时）。
import { HttpClient, ApiResponse } from '../common/HttpClient'

/** 对话入参（对应后端 AssistantController.chat 的 body） */
export interface ChatParam {
  question: string
}

/** 对话返回：reply = 助手回复文本；source = rule(关键词直答)/llm(大模型)/fallback(兜底) */
export interface ChatResult {
  reply: string
  source: string
}

export class AssistantApi {
  /** 发一句话给助手，返回回复文本 */
  static chat(question: string): Promise<ApiResponse<ChatResult>> {
    const body: ChatParam = { question: question }
    return HttpClient.postLong<ChatResult>('/api/assistant/chat', body)
  }
}
