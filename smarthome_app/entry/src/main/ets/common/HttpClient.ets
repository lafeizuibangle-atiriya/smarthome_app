// common/HttpClient.ets —— 【阶段① · C 负责】统一网络层（前端手册 4.3 节，全组最重要的一段公共代码）
//
// 职责四件事：拼 baseURL(Env.BASE_URL + path)、带 token 请求头、解析 Result、统一错误提示。
// 【铁律】页面禁止直接用它，必须通过 api/ 层调用（URL 只允许出现在 api/ 文件里）。
import { http } from '@kit.NetworkKit'
import { router, promptAction } from '@kit.ArkUI'
import { Env } from './Env'
import { TokenStore } from './TokenStore'

/** 与后端 Result 对应的统一响应结构（契约，先写它） */
export interface ApiResponse<T> {
  code: number
  msg: string
  data?: T
}

/**
 * 【轮询与 401 的三条纪律】（手册 4.3.1，都是真实踩坑）：
 *  1) 401 只有在"本地本来带着 token"时才算登录过期——未登录时的 401 是预期行为，
 *     不提示也不清 token；注意 hadToken 判断必须写在 await TokenStore.clear() 之前！
 *  2) 基础设施类提示（401/网络异常/服务异常）同一条文案 10 秒内只弹一次（Map 节流），
 *     否则 5 秒轮询会把提示变成弹幕（总方案踩坑 13）。
 *  3) 未登录不发需要登录的请求、不起轮询——页面先判 TokenStore.isLogin()。
 * 【总原则】"后台自动触发"的提示要克制；"用户主动操作"(400 业务错)每次都提示、不节流。
 * 【细节】client.destroy() 放 finally，否则连接泄漏；超时 8 秒。
 */
export class HttpClient {
  /** 同一条文案的最小弹出间隔（毫秒） */
  private static readonly TOAST_GAP_MS: number = 10000

  /** key = 提示文案，value = 上次弹出时间戳（节流用） */
  private static toastAt: Map<string, number> = new Map<string, number>()

  /** 登录态失效回调：由 Index 注册，用于让界面同步切回"未登录"形态 */
  private static authFailListener: (() => void) | null = null

  /** 注册登录态失效回调（App 启动时调用一次即可） */
  static setAuthFailListener(fn: () => void): void {
    HttpClient.authFailListener = fn
  }

  /** 带节流的提示：同一条文案 10 秒内只弹一次（用于 401 / 网络异常 / 服务异常） */
  private static notify(message: string): void {
    const now: number = Date.now()
    const last: number = HttpClient.toastAt.get(message) ?? 0
    if (now - last < HttpClient.TOAST_GAP_MS) {
      return
    }
    HttpClient.toastAt.set(message, now)
    promptAction.showToast({ message: message })
  }

  /**
   * 处理 401：清登录态 → 通知界面 →（节流后）提示一次 → 跳登录页。
   *
   * 【2026-09-27 调整】无论"本来有没有 token"，只要碰到 401 都引导去登录：
   *  · 未登录就点了需要登录的功能 → 提示"请先登录"并跳登录页（不再静默）；
   *  · 登录过期 → 提示"登录已过期"并跳登录页。
   * 修复"未登录时点击什么都报服务异常"的问题（401 曾被当成非 200 的服务异常处理）。
   */
  private static async handleUnauthorized(): Promise<void> {
    const hadToken: boolean = TokenStore.isLogin()

    if (!hadToken) {
      // 未登录：不算"过期"，不写盘、不清回调；但仍要提示 + 引导登录（用户主动点的）
      HttpClient.notify('请先登录')
      HttpClient.gotoLogin()
      return
    }

    await TokenStore.clear()
    // 通知界面：登录态已失效，相关页面要切回未登录形态并停止轮询
    if (HttpClient.authFailListener !== null) {
      HttpClient.authFailListener()
    }
    HttpClient.notify('登录已过期，请重新登录')
    HttpClient.gotoLogin()
  }

  /** 跳登录页：当前已经在登录页就不重复压栈（防止多个 401 叠出多层登录页） */
  private static gotoLogin(): void {
    try {
      const state: router.RouterState = router.getState()
      if (state.path.indexOf('LoginPage') >= 0) {
        return
      }
      router.pushUrl({ url: 'pages/login/LoginPage' })
    } catch (err) {
      // 极端时序下路由栈尚未就绪：忽略，下一个 401 请求还会再触发
    }
  }

  /**
   * 统一请求入口。四个公开方法（get/post/put/delete）都转发到这里。
   *
   * @param body 请求体。调用方必须传"有类型的对象"（api 层声明的 XxxParam interface），
   *             不能直接传裸字面量 —— 那是 ArkTS 严格模式的硬要求。
   */
  private static async request<T>(method: http.RequestMethod, path: string,
                                  body?: object): Promise<ApiResponse<T>> {
    const client: http.HttpRequest = http.createHttp()
    try {
      // 1. 组装请求头：有 token 就带上（后端拦截器靠它识别用户）
      //    注意后端读的请求头名字是 token，不是 Authorization。
      const header: Record<string, string> = { 'Content-Type': 'application/json' }
      const token: string = TokenStore.getToken()
      if (token.length > 0) {
        header['token'] = token
      }

      // 2. 组装请求参数
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        extraData: body === undefined ? undefined : JSON.stringify(body),
        connectTimeout: 8000,      // 连接超时 8 秒
        readTimeout: 8000
      }

      // 3. 发请求
      const resp: http.HttpResponse = await client.request(Env.BASE_URL + path, options)

      if (resp.responseCode === 401) {
        // 【2026-09-27 修复"未登录点什么都报服务异常"】
        // 后端 LoginInterceptor 对未登录请求回 HTTP 401（body 里同时写了 {"code":401}）。
        // 401 是"需要登录"的正常业务状态，不能再落进下面的"服务异常"分支：
        // 统一处理为 清登录态 → 节流提示 → 跳登录页。
        await HttpClient.handleUnauthorized()
        return { code: 401, msg: '请先登录' }
      }

      if (resp.responseCode !== 200) {
        // 走节流：轮询场景下服务端挂掉时不会刷屏
        HttpClient.notify(`服务异常（${resp.responseCode}）`)
        return { code: -1, msg: '服务异常' }
      }

      // 4. 解析 JSON（后端所有接口都返回 { code, msg, data }）
      const result: ApiResponse<T> = JSON.parse(resp.result as string) as ApiResponse<T>

      // 5. 统一处理特殊状态
      if (result.code === 401) {
        // 【为什么是 401 在 body 里而不是 HTTP 状态码】
        // LoginInterceptor 直接往响应体写 {"code":401}，没改 HTTP 状态，
        // 所以 HTTP 仍是 200，必须解析 body 才能发现 —— 别去改上面那个 200 判断。
        await HttpClient.handleUnauthorized()
      } else if (result.code !== 200) {
        // 400 等业务错误：这是用户主动操作触发的，必须每次都提示，所以**不节流**
        promptAction.showToast({ message: result.msg })
      }
      return result
    } catch (err) {
      // 网络异常：多半是 IP 写错、后端没启动、手机与电脑不在同一网络。
      // 同样是轮询会反复触发的情况，要节流。
      HttpClient.notify('网络异常，请检查后端服务与 IP 配置')
      return { code: -1, msg: '网络异常' }
    } finally {
      client.destroy()      // 必须销毁，否则连接会泄漏
    }
  }

  static get<T>(path: string): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(http.RequestMethod.GET, path)
  }

  static post<T>(path: string, body?: object): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(http.RequestMethod.POST, path, body)
  }

  static put<T>(path: string, body?: object): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(http.RequestMethod.PUT, path, body)
  }

  static delete<T>(path: string): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(http.RequestMethod.DELETE, path)
  }
}
