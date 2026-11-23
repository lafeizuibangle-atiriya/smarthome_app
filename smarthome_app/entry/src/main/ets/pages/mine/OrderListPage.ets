// pages/mine/OrderListPage.ets —— 订单列表页（@Entry 子页面，手册 6.17）
// 状态 Tab（全部/待付款/已付款/已完成）、订单卡片、待付款可取消订单。
// 【关键】ForEach 的 key 拼上 status，否则取消后状态文字不变（踩坑 14）。
import { router, promptAction } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { Order, OrderItem } from '../../model/Shop'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'
import { TokenStore } from '../../common/TokenStore'
import { EmptyView } from '../../view/EmptyView'

interface OrderParams {
  status?: number
}

interface StatusTab {
  label: string
  value: number      // -1 全部
}

@Entry
@Component
struct OrderListPage {
  @State tabs: StatusTab[] = [
    { label: '全部', value: -1 },
    { label: '待付款', value: 0 },
    { label: '已付款', value: 1 },
    { label: '已完成', value: 2 }
  ]
  @State currentTab: number = 0
  @State orders: Order[] = []

  aboutToAppear() {
    const params = router.getParams() as OrderParams
    if (params && params.status !== undefined) {
      const index: number = this.tabs.findIndex((t: StatusTab) => t.value === params.status)
      if (index >= 0) {
        this.currentTab = index
      }
    }
    this.load()
  }

  async load() {
    if (!TokenStore.isLogin()) {
      promptAction.showToast({ message: '请先登录' })
      return
    }
    const res = await ShopApi.orderList(this.tabs[this.currentTab].value)
    if (res.code === 200 && res.data) {
      this.orders = res.data
    }
  }

  /** 订单状态文案 */
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

  /** 取消订单（回滚库存）：用户主动操作且留在本页 → 明确 toast（手册 4.3.2） */
  async cancelOrder(order: Order) {
    const res = await ShopApi.cancelOrder(order.id)
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
        Text('我的订单').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      // 状态 Tab
      Row({ space: 20 }) {
        ForEach(this.tabs, (tab: StatusTab, index: number) => {
          Column({ space: 4 }) {
            Text(tab.label).fontSize(14)
              .fontColor(index === this.currentTab ? Const.BRAND : Const.TEXT_SUB)
            // 选中态下划线
            Divider().width(20)
              .color(index === this.currentTab ? Const.BRAND : Color.Transparent)
              .strokeWidth(2)
          }.onClick(() => {
            this.currentTab = index
            this.load()
          })
        }, (tab: StatusTab) => tab.label)
      }.width('100%').padding({ left: 16, bottom: 8 })

      if (this.orders.length === 0) {
        EmptyView({ text: '还没有订单', buttonText: '去商城逛逛',
          onAction: () => {
            router.replaceUrl({ url: 'pages/Index' })
          } })
      } else {
        List({ space: Const.CARD_GAP }) {
          ForEach(this.orders, (order: Order) => {
            ListItem() {
              Column({ space: 10 }) {
                Row() {
                  Text(`订单号：${order.orderNo}`).fontSize(12).fontColor(Const.TEXT_SUB)
                  Blank()
                  Text(this.statusText(order.status)).fontSize(13)
                    .fontColor(order.status === 0 ? Const.BRAND : Const.TEXT_SUB)
                }.width('100%')

                ForEach(order.items, (item: OrderItem, index: number) => {
                  Row({ space: 10 }) {
                    Image(item.goodsCover).width(56).height(56)
                      .borderRadius(8).backgroundColor('#F5F5F5').objectFit(ImageFit.Cover)
                      .alt($r('app.media.img_placeholder'))
                    Column({ space: 4 }) {
                      Text(item.goodsName).fontSize(13).maxLines(1)
                      Text(`x${item.quantity}`).fontSize(11).fontColor(Const.TEXT_SUB)
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Text(Format.money(item.price)).fontSize(13)
                  }.width('100%')
                }, (item: OrderItem, index: number) => `${item.goodsId}_${index}`)

                Row() {
                  Text(order.createTime).fontSize(11).fontColor(Const.TEXT_SUB)
                  Blank()
                  if (order.status === 0) {
                    Text('取消订单').fontSize(13).fontColor(Const.DANGER)
                      .padding({ left: 10, right: 10 })
                      .onClick(() => {
                        this.cancelOrder(order)
                      })
                    Text('去支付').fontSize(13).fontColor(Const.BRAND)
                      .padding({ left: 10, right: 10 })
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/shop/PayPage',
                          params: { orderId: order.id, amount: order.totalAmount }
                        })
                      })
                  }
                  Text('合计 ').fontSize(12)
                  Text(Format.money(order.totalAmount)).fontSize(15)
                    .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
                }.width('100%')
              }
              .padding(14).backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/mine/OrderDetailPage', params: { orderId: order.id }
                })
              })
            }
          }, (order: Order) => `${order.id}_${order.status}`)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').padding({ left: 16, right: 16 }).backgroundColor(Const.PAGE_BG)
  }
}
