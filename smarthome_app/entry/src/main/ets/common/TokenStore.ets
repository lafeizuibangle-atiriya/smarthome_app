// common/TokenStore.ets —— 【阶段① · C 负责】登录态存储：内存 + Preferences 双写
//
// 设计要点：token 同时存在内存和 Preferences 中——
//   内存供 HttpClient 同步读取（避免每次请求都异步读磁盘），
//   Preferences 用于 App 重启后恢复登录态。
// 纪律：save() / clear() 之后必须 await flush()，否则可能没真正落盘，
//       杀进程重开就"登录态丢了"（阶段① 完成判定就是测这一条）。
import { preferences } from '@kit.ArkData'

const STORE_NAME: string = 'smarthome_user'
const KEY_TOKEN: string = 'token'
const KEY_NICKNAME: string = 'nickname'
const KEY_LAST_ACCOUNT: string = 'lastAccount'   // 上次登录的账号（只存账号，绝不存密码）

export class TokenStore {
  private static token: string = ''
  private static nickname: string = ''
  private static lastAccount: string = ''
  /** 缓存 Preferences 实例，避免每次读写都走一遍 getPreferences */
  private static pref: preferences.Preferences | null = null

  /**
   * 取 Preferences 实例（懒加载 + 缓存）。
   * 说明：getContext() 在 API 12 已标记废弃，会报 WARN，但不阻塞编译。
   *      若后续要消掉 WARN，可改为在 EntryAbility 里把 context 传进来。
   */
  private static async store(): Promise<preferences.Preferences> {
    if (TokenStore.pref === null) {
      TokenStore.pref = await preferences.getPreferences(getContext(), STORE_NAME)
    }
    return TokenStore.pref
  }

  /** App 启动时调用一次，从本地恢复登录态（Index.aboutToAppear 里调） */
  static async init(): Promise<void> {
    const pref: preferences.Preferences = await TokenStore.store()
    TokenStore.token = await pref.get(KEY_TOKEN, '') as string
    TokenStore.nickname = await pref.get(KEY_NICKNAME, '') as string
    TokenStore.lastAccount = await pref.get(KEY_LAST_ACCOUNT, '') as string
  }

  /** 同步读取 token，供 HttpClient 使用（这是"内存那份"存在的意义） */
  static getToken(): string {
    return TokenStore.token
  }

  static getNickname(): string {
    return TokenStore.nickname
  }

  /** 是否已登录：UI 判断登录态统一用这个方法，不要各写各的 */
  static isLogin(): boolean {
    return TokenStore.token.length > 0
  }

  /** 上次登录的账号（登录页预填用；只存账号不存密码，2026-09-29 新增） */
  static getLastAccount(): string {
    return TokenStore.lastAccount
  }

  /** 登录成功后记住账号（异步落盘，页面里 await 一下更稳） */
  static async saveLastAccount(account: string): Promise<void> {
    TokenStore.lastAccount = account
    const pref: preferences.Preferences = await TokenStore.store()
    await pref.put(KEY_LAST_ACCOUNT, account)
    await pref.flush()
  }

  /** 登录成功后保存 */
  static async save(token: string, nickname: string): Promise<void> {
    // 先写内存：写完之后 isLogin() 立刻为 true，UI 不用等磁盘
    TokenStore.token = token
    TokenStore.nickname = nickname
    const pref: preferences.Preferences = await TokenStore.store()
    await pref.put(KEY_TOKEN, token)
    await pref.put(KEY_NICKNAME, nickname)
    await pref.flush()          // 必须 flush，否则可能没真正落盘
  }

  /** 退出登录 / 登录过期：清内存 + 清本地 */
  static async clear(): Promise<void> {
    // 注意：这两行是**同步**的。HttpClient 判断"本来有没有 token"
    // 必须写在 await TokenStore.clear() 之前，写后面就永远是"没有 token"。
    TokenStore.token = ''
    TokenStore.nickname = ''
    const pref: preferences.Preferences = await TokenStore.store()
    await pref.delete(KEY_TOKEN)
    await pref.delete(KEY_NICKNAME)
    await pref.flush()
  }
}
