// pages/shop/PayPage.ets —— 模拟支付页（@Entry 子页面，自研实现）
// 从订单详情/订单列表的"待付款"订单进入：显示金额 + 模拟支付按钮。
// 点支付 → ShopApi.payOrder（后端直接把状态改为已付款）→ 2 秒 loading → 支付结果页。
// 【约定】支付是用户主动操作且会跳结果页 → 结果页就是反馈，本页不再 Toast（手册 4.3.2）。
import { router } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'

interface PayParams {
  orderId: number
  amount: number
}

@Entry
@Component
struct PayPage {
  @State orderId: number = 0
  @State amount: number = 0
  @State paying: boolean = false

  aboutToAppear() {
    const params = router.getParams() as PayParams
    this.orderId = params.orderId
    this.amount = params.amount
  }

  /** 模拟支付：调后端改状态 → 2 秒 loading → 跳结果页 */
  async pay() {
    if (this.paying) {
      return          // 防重复提交
    }
    this.paying = true
    const res = await ShopApi.payOrder(this.orderId)
    // 固定 2 秒，让"支付中"的 loading 可感知（模拟真实支付耗时）
    setTimeout(() => {
      this.paying = false
      if (res.code === 200) {
        router.replaceUrl({
          url: 'pages/shop/PayResultPage',
          params: { orderNo: '', amount: this.amount }
        })
      }
    }, 2000)
  }

  build() {
    Column({ space: 20 }) {
      Text('模拟支付').fontSize(18).fontWeight(FontWeight.Medium)
        .margin({ top: 80 })

      Column({ space: 8 }) {
        Text('应付金额').fontSize(13).fontColor(Const.TEXT_SUB)
        Text(Format.money(this.amount)).fontSize(36)
          .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
      }
      .padding(32)
      .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
      .margin({ top: 12 })

      Text('本页面为课程 Demo 的模拟支付，不会产生真实交易。')
        .fontSize(11).fontColor(Const.TEXT_SUB)

      Blank()

      Button(this.paying ? '支付中...' : '确认支付')
        .width('80%').height(46).borderRadius(23)
        .backgroundColor(Const.BRAND).fontColor(Color.White)
        .enabled(!this.paying)
        .margin({ bottom: 60 })
        .onClick(() => {
          this.pay()
        })
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
