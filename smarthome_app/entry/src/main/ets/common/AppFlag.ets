// common/AppFlag.ets —— 跨页面共享的运行标志
//
// 【为什么必须放在独立文件里当 static 字段】
// 广告页结束后是 router.replaceUrl 回 pages/Index，旧的 Index 实例会被销毁。
// 如果标志写成 Index 的成员变量，它跟着实例一起重置 ——
// 新的 Index 又会跳一次广告，形成 Index → 广告 → Index → 广告 … 死循环。
// static 字段属于类本身、进程内只有一份，与页面实例的生死无关，
// 因此能保证「一次冷启动只弹一次广告」（重启 App 后重新弹）。
export class AppFlag {
  /** 广告页是否已经展示过 */
  static adShown: boolean = false
}
