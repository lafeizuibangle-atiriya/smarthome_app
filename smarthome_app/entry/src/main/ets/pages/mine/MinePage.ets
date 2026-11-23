// pages/mine/MinePage.ets —— 【阶段① · D 负责】底部 Tab·我的（@Component，由 Index 内嵌承载，不是 @Entry！）
// 两态页面：未登录置灰 + 引导登录；已登录显示昵称/统计 + 功能入口 + 退出登录。
// 结构照手册 6.14（状态 → 生命周期 → 请求 → build），不要自创写法。
import { router, promptAction } from '@kit.ArkUI'   // promptAction 别忘了导，漏了就是 Cannot find name
import { UserApi } from '../../api/UserApi'
import { UserInfo } from '../../model/User'
import { Const } from '../../common/Const'
import { TokenStore } from '../../common/TokenStore'

@Component
export struct MinePage {
  @State userInfo: UserInfo | null = null
  @State isLogin: boolean = false

  /**
   * 来自 Index 的刷新信号（见 Index.ets 里 refreshTick 的注释）。
   *
   * Tab 子页面没有 onPageShow，aboutToAppear 又只在首次创建时跑一次，
   * 所以「登录 → router.back() 回到我的页」时本组件不会自动刷新，
   * isLogin 会一直停在登录前的 false，看起来就像"登录没成功"。
   * @Prop 负责父→子单向同步，@Watch 负责在信号变化时重新拉数据，两个必须成对出现。
   */
  @Prop @Watch('onRefreshTick') refreshTick: number = 0

  /** 退出登录后通知 Index 广播一次刷新，让首页/智能页也切回未登录形态 */
  onLogout: () => void = () => {}

  /** 刷新信号变化时重新拉登录态 */
  onRefreshTick() {
    this.refresh()
  }

  // 首次创建时也要拉一次（此时 @Watch 还没被触发过）
  aboutToAppear() {
    this.refresh()
  }

  /** 刷新登录态与用户信息 */
  async refresh() {
    this.isLogin = TokenStore.isLogin()
    if (this.isLogin) {
      const res = await UserApi.info()
      if (res.code === 200 && res.data) {
        this.userInfo = res.data
      } else {
        // 请求失败（典型是 token 失效返回 401）：
        // HttpClient 已经清掉本地 token，这里必须同步 UI 状态，
        // 否则会停在"显示已登录、但一个数据都没有"的假象里。
        this.userInfo = null
        this.isLogin = TokenStore.isLogin()
      }
    } else {
      this.userInfo = null      // 退出登录后清空，避免残留上一个用户数据
    }
  }

  /** 需要登录的功能统一走这里 */
  goWithLogin(url: string) {
    if (!this.isLogin) {
      promptAction.showToast({ message: '请先登录' })
      router.pushUrl({ url: 'pages/login/LoginPage' })
      return
    }
    router.pushUrl({ url: url })
  }

  @Builder
  menuItem(title: string, subtitle: string, url: string, needLogin: boolean) {
    Row() {
      Text(title).fontSize(15)
        .fontColor(needLogin && !this.isLogin ? Const.TEXT_SUB : Const.TEXT_MAIN)
      Blank()
      Text(subtitle).fontSize(12).fontColor(Const.TEXT_SUB)
      Text('›').fontSize(16).fontColor('#CCCCCC').margin({ left: 6 })
    }
    .width('100%').padding(16)
    .backgroundColor(Const.CARD_BG)
    .onClick(() => {
      if (needLogin) {
        this.goWithLogin(url)
      } else {
        router.pushUrl({ url: url })
      }
    })
  }

  build() {
    Column() {
      // ---------- 顶部用户区：两态差异 ----------
      Row({ space: 12 }) {
        // 未登录用灰色占位头像，已登录用主色
        Circle({ width: 56, height: 56 })
          .fill(this.isLogin ? Const.BRAND : '#DDDDDD')
        Column({ space: 4 }) {
          if (this.isLogin) {
            // 优先用接口拿到的真实昵称；接口还没回来时退回本地存的（登录页暂存）
            Text(this.userInfo?.nickname ?? TokenStore.getNickname())
              .fontSize(18).fontWeight(FontWeight.Medium)
            Text(`设备 ${this.userInfo?.deviceCount ?? 0} 台 · 订单 ${this.userInfo?.orderCount ?? 0} 笔`)
              .fontSize(12).fontColor(Const.TEXT_SUB)
          } else {
            Text('登录 / 注册').fontSize(18).fontWeight(FontWeight.Medium)
            Text('登录后管理设备与订单').fontSize(12).fontColor(Const.TEXT_SUB)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        if (!this.isLogin) {
          Button('去登录')
            .height(32).borderRadius(16).fontSize(13)
            .backgroundColor(Const.BRAND).fontColor(Color.White)
            .onClick(() => { router.pushUrl({ url: 'pages/login/LoginPage' }) })
        }
      }
      .width('100%').padding(20)
      .margin({ left: 16, right: 16, top: 12 })
      .backgroundColor(Const.CARD_BG)
      .borderRadius(Const.CARD_RADIUS)

      // ---------- 订单快捷入口（数字全部来自 /api/user/info 的实时统计）----------
      Row() {
        Column({ space: 4 }) {
          Text('待付款').fontSize(12).fontColor(Const.TEXT_SUB)
          Text(this.isLogin ? String(this.userInfo?.orderPending ?? 0) : '--').fontSize(15)
        }.layoutWeight(1).onClick(() => { this.goWithLogin('pages/mine/OrderListPage') })

        Column({ space: 4 }) {
          Text('已付款').fontSize(12).fontColor(Const.TEXT_SUB)
          Text(this.isLogin ? String(this.userInfo?.orderPaid ?? 0) : '--').fontSize(15)
        }.layoutWeight(1).onClick(() => { this.goWithLogin('pages/mine/OrderListPage') })

        Column({ space: 4 }) {
          Text('全部订单').fontSize(12).fontColor(Const.TEXT_SUB)
          Text(this.isLogin ? String(this.userInfo?.orderCount ?? 0) : '--').fontSize(15)
        }.layoutWeight(1).onClick(() => { this.goWithLogin('pages/mine/OrderListPage') })
      }
      .width('100%').padding(16)
      .margin({ left: 16, right: 16, top: 12 })
      .backgroundColor(Const.CARD_BG)
      .borderRadius(Const.CARD_RADIUS)

      // ---------- 功能列表 ----------
      Column() {
        this.menuItem('我的设备', this.isLogin ? '管理' : '需登录', 'pages/home/RoomManagePage', true)
        Divider().color(Const.DIVIDER).margin({ left: 16 })
        this.menuItem('我的订单', this.isLogin ? '查看' : '需登录', 'pages/mine/OrderListPage', true)
        Divider().color(Const.DIVIDER).margin({ left: 16 })
        this.menuItem('收货地址', this.isLogin ? '管理' : '需登录', 'pages/mine/SettingsPage', true)
        Divider().color(Const.DIVIDER).margin({ left: 16 })
        this.menuItem('设置', '可直接进入', 'pages/mine/SettingsPage', false)
      }
      .width('100%').margin({ left: 16, right: 16, top: 12 })
      .borderRadius(Const.CARD_RADIUS).clip(true)

      // ---------- 退出登录（仅登录态显示）----------
      if (this.isLogin) {
        Button('退出登录')
          .width('92%').height(44).borderRadius(22).margin({ top: 24 })
          .backgroundColor(Const.CARD_BG).fontColor(Const.DANGER)
          .onClick(async () => {
            await TokenStore.clear()
            await this.refresh()
            // 通知 Index 广播信号：首页/智能页也要切回未登录形态
            this.onLogout()
            promptAction.showToast({ message: '已退出登录' })
          })
      }

      Blank()
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
