// pages/Index.ets —— 【阶段① · C 负责】主框架：底部 5 个 Tab（@Entry）
// 补全内容：refreshTick 广播 + aboutToAppear 里 TokenStore.init().then(...)
//          + Tab 图标换 Image($r) + HttpClient.setAuthFailListener
import { router } from '@kit.ArkUI'
import { TokenStore } from '../common/TokenStore'
import { HttpClient } from '../common/HttpClient'
import { Const } from '../common/Const'
import { AppFlag } from '../common/AppFlag'
import { HomePage } from './home/HomePage'
import { SmartPage } from './smart/SmartPage'
import { ProductPage } from './product/ProductPage'
import { ShopPage } from './shop/ShopPage'
import { MinePage } from './mine/MinePage'

interface TabItem {
  title: string
  icon: Resource
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0
  /**
   * 刷新信号：每 +1 表示「当前 Tab 该重新拉一次数据」。
   *
   * 【为什么必须有它】Tabs 内嵌的子页面是 @Component 而不是 @Entry，
   * 它们没有 onPageShow 生命周期，aboutToAppear 又只在整个 Tab 首次创建时跑一次。
   * 结果：从登录页 router.back() 回来时，MinePage 不会重新执行 refresh()，
   * 它的 @State isLogin 还停在登录前的 false —— 表现就是
   * **弹出"登录成功"提示、页面却依然显示未登录**，很容易被误判成"请求没发出去"。
   * 所以由 @Entry 的 Index 统一广播信号，子组件用 @Prop + @Watch 接收。
   * （总方案踩坑 11）
   */
  @State refreshTick: number = 0

  private tabs: TabItem[] = [
    { title: '主页', icon: $r('app.media.ic_tab_home') },
    { title: '智能', icon: $r('app.media.ic_tab_smart') },
    { title: '产品', icon: $r('app.media.ic_tab_product') },
    { title: '商城', icon: $r('app.media.ic_tab_shop') },
    { title: '我的', icon: $r('app.media.ic_tab_mine') }
  ]

  aboutToAppear() {
    // ---------- 冷启动先弹广告页 ----------
    // 启动首屏仍是 pages/Index（EntryAbility.loadContent 里写死的），
    // 但第一件事就是跳广告：用 replaceUrl 而不是 pushUrl ——
    // push 会把 Index 压在栈底，广告结束后用户一按返回键就退回这个"空壳 Index"。
    // replace 直接让 AdPage 顶替掉 Index，页面栈里干干净净只剩它。
    // AppFlag.adShown 兜住"广告结束 replace 回 Index"这一次重入，
    // 保证每次冷启动只弹一次（详见 common/AppFlag.ets 的注释）。
    if (!AppFlag.adShown) {
      AppFlag.adShown = true
      router.replaceUrl({ url: 'pages/AdPage' })
      return
    }

    // token 失效时由 HttpClient 回调到这里：广播一次刷新，
    // 让各个 Tab 切回"未登录"形态并停掉轮询（不然会一直 401 刷屏）
    HttpClient.setAuthFailListener(() => {
      this.refreshTick++
    })
    // 启动时恢复登录态（token 从本地读进内存）。
    // init 是异步的，必须等它读完再广播信号——否则子页面会在 token 还没加载出来时
    // 就判断成"未登录"，重启 App 后登录态看着就丢了（阶段① 完成判定就是测这一条）。
    TokenStore.init().then(() => {
      this.refreshTick++
    })
  }

  /** 从登录页 / 详情页 router.back() 回到本页时触发 */
  onPageShow() {
    this.refreshTick++
  }

  /** 自定义 Tab 按钮：图标 + 文字，选中态用主色（米家蓝） */
  @Builder
  tabBuilder(index: number, item: TabItem) {
    Column({ space: 2 }) {
      // fillColor 对 SVG 图标生效，一套图标就能同时表达选中/未选中
      Image(item.icon).width(22).height(22)
        .fillColor(this.currentIndex === index ? Const.BRAND : Const.TEXT_SUB)
      Text(item.title).fontSize(11)
        .fontColor(this.currentIndex === index ? Const.BRAND : Const.TEXT_SUB)
    }.justifyContent(FlexAlign.Center).height('100%').width('100%')
  }

  build() {
    // Tabs 组件 + barPosition.End 实现底部导航
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      // visible：只让"看得见"的那个 Tab 轮询，切走的页面停止轮询（省电省流量，踩坑 13）
      TabContent() {
        HomePage({ refreshTick: this.refreshTick, visible: this.currentIndex === 0 })
      }.tabBar(this.tabBuilder(0, this.tabs[0]))

      TabContent() {
        SmartPage({ refreshTick: this.refreshTick })
      }.tabBar(this.tabBuilder(1, this.tabs[1]))

      TabContent() {
        ProductPage()
      }.tabBar(this.tabBuilder(2, this.tabs[2]))

      TabContent() {
        ShopPage()
      }.tabBar(this.tabBuilder(3, this.tabs[3]))

      // 我的页显示登录态，必须接收刷新信号（见上面 refreshTick 的注释）；
      // onLogout 用于"退出登录"后让首页/智能页也切回未登录形态
      TabContent() {
        MinePage({
          refreshTick: this.refreshTick,
          onLogout: () => {
            this.refreshTick++
          }
        })
      }.tabBar(this.tabBuilder(4, this.tabs[4]))
    }
    .barHeight(56)
    .barBackgroundColor(Const.CARD_BG)      // 米家风格：白色导航条，与浅灰页面拉开层次
    .backgroundColor(Const.PAGE_BG)
    .onChange((index: number) => {
      this.currentIndex = index
      this.refreshTick++      // 切 Tab 时也刷新一次，保证看到最新状态
    })
  }
}
