// pages/mine/OrderDetailPage.ets —— 订单详情页（@Entry 子页面，手册 6.17.1 + 自研补全）
// 单笔订单状态、下单时收货信息快照、商品明细、金额合计；
// 待付款可「去支付 / 取消订单」。从订单列表带 orderId 路由进入。
// 【约定】支付/取消都是用户主动操作且留在本页 → 必须明确 toast，然后重新 load（手册 4.3.2）。
import { router, promptAction } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { Order, OrderItem } from '../../model/Shop'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'
import { EmptyView } from '../../view/EmptyView'

// 路由入参必须先声明 interface（ArkTS 严格模式，手册 5.0 ①）
interface OrderDetailParams {
  orderId: number
}

@Entry
@Component
struct OrderDetailPage {
  @State order: Order | null = null
  private orderId: number = 0

  aboutToAppear() {
    const params = router.getParams() as OrderDetailParams
    this.orderId = params.orderId
    this.load()
  }

  async load() {
    const res = await ShopApi.orderDetail(this.orderId)
    if (res.code === 200 && res.data) {
      this.order = res.data
    }
  }

  statusText(status: number): string {
    if (status === 0) {
      return '待付款'
    }
    if (status === 1) {
      return '已付款'
    }
    if (status === 2) {
      return '已完成'
    }
    return '已取消'
  }

  statusColor(status: number): string {
    if (status === 0) {
      return Const.BRAND
    }
    if (status === 1) {
      return Const.SUCCESS
    }
    if (status === 2) {
      return Const.TEXT_MAIN
    }
    return Const.TEXT_SUB
  }

  /** 支付：跳模拟支付页 */
  goPay() {
    if (this.order === null) {
      return
    }
    router.pushUrl({
      url: 'pages/shop/PayPage',
      params: { orderId: this.order.id, amount: this.order.totalAmount }
    })
  }

  /** 取消订单（回滚库存） */
  async cancel() {
    if (this.order === null) {
      return
    }
    const res = await ShopApi.cancelOrder(this.order.id)
    if (res.code === 200) {
      promptAction.showToast({ message: '订单已取消' })
      this.load()
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('订单详情').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.order === null) {
        EmptyView({ text: '订单不存在或已删除' })
      } else {
        Scroll() {
          Column({ space: Const.CARD_GAP }) {
            // ---------- 状态卡 ----------
            Row() {
              Text(this.statusText(this.order!.status)).fontSize(18)
                .fontWeight(FontWeight.Medium).fontColor(this.statusColor(this.order!.status))
              Blank()
              Text(this.order!.createTime).fontSize(12).fontColor(Const.TEXT_SUB)
            }
            .width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 收货信息（下单时快照，改地址不影响历史订单）----------
            Column({ space: 6 }) {
              Text('收货信息').fontSize(14).fontWeight(FontWeight.Medium)
              Text(`${this.order!.receiverName ?? '--'}　${this.order!.receiverPhone ?? '--'}`)
                .fontSize(13)
              Text(this.order!.receiverAddress ?? '--')
                .fontSize(12).fontColor(Const.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start).width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 商品明细 ----------
            Column({ space: 10 }) {
              ForEach(this.order!.items, (item: OrderItem, index: number) => {
                Row({ space: 10 }) {
                  Image(item.goodsCover).width(56).height(56)
                    .borderRadius(8).backgroundColor('#F5F5F5').objectFit(ImageFit.Cover)
                    .alt($r('app.media.img_placeholder'))
                  Column({ space: 4 }) {
                    Text(item.goodsName).fontSize(13).maxLines(1)
                    Text(`x${item.quantity}`).fontSize(11).fontColor(Const.TEXT_SUB)
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text(Format.money(item.price * item.quantity)).fontSize(13)
                }.width('100%')
              }, (item: OrderItem, index: number) => `${item.goodsId}_${index}`)
            }
            .width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 金额 ----------
            Row() {
              Text('订单编号').fontSize(12).fontColor(Const.TEXT_SUB)
              Blank()
              Text(this.order!.orderNo).fontSize(12).fontColor(Const.TEXT_SUB)
            }
            .width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            Row() {
              Text('实付金额').fontSize(14)
              Blank()
              Text(Format.money(this.order!.totalAmount)).fontSize(18)
                .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
            }
            .width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            Text('提示：收货人信息为下单时的快照，之后修改地址不影响本订单。')
              .fontSize(11).fontColor(Const.TEXT_SUB)
          }.padding({ left: 16, right: 16, bottom: 80 })
        }.layoutWeight(1).scrollBar(BarState.Off)

        // ---------- 底部操作栏：待付款才显示 ----------
        if (this.order!.status === 0) {
          Row({ space: 12 }) {
            Button('取消订单')
              .layoutWeight(1).height(42).borderRadius(21)
              .backgroundColor(Const.CARD_BG).fontColor(Const.DANGER)
              .border({ width: 1, color: Const.DANGER })
              .onClick(() => {
                this.cancel()
              })
            Button('去支付')
              .layoutWeight(1).height(42).borderRadius(21)
              .backgroundColor(Const.BRAND).fontColor(Color.White)
              .onClick(() => {
                this.goPay()
              })
          }
          .width('100%').padding(16).backgroundColor(Const.CARD_BG)
        }
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
