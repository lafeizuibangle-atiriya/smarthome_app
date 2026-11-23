// pages/shop/PayResultPage.ets —— 支付结果页（@Entry 子页面，手册 6.13）
// 成功图标 + 订单号 + 「查看订单 / 返回首页」。
// 改数据后跳结果页的，本页就是反馈，不再 Toast（前端手册 4.3.2）。
import { router } from '@kit.ArkUI'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'

interface ResultParams {
  orderNo: string
  amount: number
}

@Entry
@Component
struct PayResultPage {
  @State orderNo: string = ''
  @State amount: number = 0

  aboutToAppear() {
    const params = router.getParams() as ResultParams
    this.orderNo = params.orderNo
    this.amount = params.amount
  }

  build() {
    Column({ space: 16 }) {
      // 成功标记：Demo 用色块表示，正式项目换成对勾图标
      Circle({ width: 64, height: 64 }).fill(Const.SUCCESS).margin({ top: 80 })
      Text('支付成功').fontSize(20).fontWeight(FontWeight.Medium)
      Text(`订单号：${this.orderNo}`).fontSize(13).fontColor(Const.TEXT_SUB)
      Text(`实付金额：${Format.money(this.amount)}`).fontSize(14)

      Row({ space: 12 }) {
        Button('查看订单')
          .layoutWeight(1).height(42).borderRadius(21)
          .backgroundColor(Const.CARD_BG).fontColor(Const.BRAND)
          .border({ width: 1, color: Const.BRAND })
          .onClick(() => {
            router.replaceUrl({
              url: 'pages/mine/OrderListPage', params: { status: -1 }
            })
          })
        Button('返回首页')
          .layoutWeight(1).height(42).borderRadius(21)
          .backgroundColor(Const.BRAND).fontColor(Color.White)
          .onClick(() => {
            router.replaceUrl({ url: 'pages/Index' })
          })
      }.width('80%').margin({ top: 12 })
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
