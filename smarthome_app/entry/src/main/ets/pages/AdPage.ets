// pages/AdPage.ets —— 启动广告页（打开 App 的第一屏）
// 需求：打开软件就是广告；右上角「跳过」；5 秒后自动跳转首页（2026-09-29 由 15 秒缩短）；
//       跳转用 replaceUrl —— 广告页被销毁、无法返回（返回键也被拦截）。
import { router } from '@kit.ArkUI'
import { Const } from '../common/Const'

@Entry
@Component
struct AdPage {
  /** 倒计时剩余秒数（需求：5 秒） */
  @State seconds: number = 5
  private timerId: number = -1

  private static readonly TOTAL_SECONDS: number = 5

  aboutToAppear() {
    this.startCountdown()
  }

  aboutToDisappear() {
    this.stopCountdown()      // 跳转销毁时清定时器，防泄漏
  }

  startCountdown() {
    this.timerId = setInterval(() => {
      this.seconds--
      if (this.seconds <= 0) {
        this.enterApp()
      }
    }, 1000)
  }

  stopCountdown() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /**
   * 进入主界面。
   * 【关键】用 replaceUrl 而不是 pushUrl：
   * replace 会用 Index 替换掉页面栈里的 AdPage —— 广告页销毁，
   * 用户在 Index 按"返回"只会退出 App，绝不会回到广告页。
   */
  enterApp() {
    this.stopCountdown()
    router.replaceUrl({ url: 'pages/Index' })
  }

  /** 拦截返回键/侧滑：广告期间不允许返回（跳转后页面已销毁，天然无法返回） */
  onBackPress(): boolean {
    return true
  }

  build() {
    // alignContent=TopEnd：让"跳过"按钮贴住右上角。
    // 不加的话 Stack 默认 Center，Row 是内容高度会被垂直居中到屏幕中部偏上。
    Stack({ alignContent: Alignment.TopEnd }) {
      // ---------- 全屏广告图 ----------
      Image($r('app.media.img_ad'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // ---------- 右上角跳过按钮 ----------
      Row() {
        Text(`跳过 ${this.seconds}`)
          .fontSize(13).fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor('rgba(0,0,0,0.45)')
          .borderRadius(Const.PILL_RADIUS)
          .onClick(() => {
            this.enterApp()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ top: 48, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
