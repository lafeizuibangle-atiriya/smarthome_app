// pages/shop/OrderConfirmPage.ets —— 确认订单页（@Entry 子页面，手册 6.12）
// 收货地址卡、商品清单、金额明细、提交订单按钮。
// 两个入口：① 购物车结算（cartItems JSON）② 商品详情"立即购买"（goodsId + quantity）。
import { router, promptAction } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { UserApi } from '../../api/UserApi'
import { CartItem, OrderItemParam } from '../../model/Shop'
import { Address } from '../../model/User'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'
import { TokenStore } from '../../common/TokenStore'

interface ConfirmParams {
  goodsId?: number       // 立即购买时传
  quantity?: number
  cartItems?: string     // 购物车结算时传（JSON 字符串）
}

@Entry
@Component
struct OrderConfirmPage {
  @State address: Address | null = null
  @State items: CartItem[] = []
  @State submitting: boolean = false
  private params: ConfirmParams = {}

  aboutToAppear() {
    this.params = router.getParams() as ConfirmParams
    this.loadAddress()
    this.buildItems()
  }

  async loadAddress() {
    const res = await UserApi.addressList()
    if (res.code === 200 && res.data && res.data.length > 0) {
      // 优先取默认地址
      const def = res.data.find((a: Address) => a.isDefault === 1)
      this.address = def !== undefined ? def : res.data[0]
    }
  }

  /** 组装待下单商品：来自购物车结算或"立即购买" */
  async buildItems() {
    if (this.params.cartItems) {
      this.items = JSON.parse(this.params.cartItems) as CartItem[]
    } else if (this.params.goodsId !== undefined) {
      // 立即购买：按 goodsId 拉商品，现场拼一条"购物车项"
      const res = await ShopApi.goodsDetail(this.params.goodsId)
      if (res.code === 200 && res.data) {
        const item: CartItem = {
          id: 0,
          goodsId: res.data.id,
          goodsName: res.data.name,
          goodsCover: res.data.cover,
          price: res.data.price,
          quantity: this.params.quantity ?? 1,
          checked: true
        }
        this.items = [item]
      }
    }
  }

  totalAmount(): number {
    let total: number = 0
    this.items.forEach((item: CartItem) => {
      total += item.price * item.quantity
    })
    return total
  }

  /** 提交订单 → 模拟支付 → 跳支付结果页 */
  async submit() {
    if (!TokenStore.isLogin()) {
      router.pushUrl({ url: 'pages/login/LoginPage' })
      return
    }
    if (this.address === null) {
      promptAction.showToast({ message: '请先在"我的-收货地址"里添加地址' })
      return
    }
    if (this.items.length === 0) {
      promptAction.showToast({ message: '没有可结算的商品' })
      return
    }
    this.submitting = true
    // ⚠️ 禁止 object[]：先声明 OrderItemParam 再 map（手册 5.0 ⑤）
    const orderItems: OrderItemParam[] = this.items.map((item: CartItem) => {
      const orderItem: OrderItemParam = { goodsId: item.goodsId, quantity: item.quantity }
      return orderItem
    })
    const res = await ShopApi.createOrder(this.address!.id, orderItems)
    this.submitting = false

    if (res.code === 200 && res.data) {
      const order = res.data
      // 创建成功 → 立刻调"模拟支付"接口
      const payRes = await ShopApi.payOrder(order.id)
      if (payRes.code === 200) {
        router.replaceUrl({
          url: 'pages/shop/PayResultPage',
          params: { orderNo: order.orderNo, amount: order.totalAmount }
        })
      }
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('确认订单').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      Scroll() {
        Column({ space: Const.CARD_GAP }) {
          // 收货地址
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              if (this.address !== null) {
                Text(`${this.address!.receiver}　${this.address!.phone}`).fontSize(14)
                Text(`${this.address!.region} ${this.address!.detail}`)
                  .fontSize(12).fontColor(Const.TEXT_SUB)
              } else {
                Text('还没有收货地址').fontSize(14).fontColor(Const.TEXT_SUB)
                Text('去"我的-收货地址"添加').fontSize(12).fontColor(Const.TEXT_SUB)
              }
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('管理').fontSize(13).fontColor(Const.BRAND)
              .onClick(() => {
                router.pushUrl({ url: 'pages/mine/SettingsPage' })
              })
          }
          .width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // 商品清单
          Column({ space: 12 }) {
            ForEach(this.items, (item: CartItem) => {
              Row({ space: 10 }) {
                Image(item.goodsCover).width(60).height(60)
                  .borderRadius(8).backgroundColor('#F5F5F5').objectFit(ImageFit.Cover)
                  .alt($r('app.media.img_placeholder'))
                Column({ space: 4 }) {
                  Text(item.goodsName).fontSize(14).maxLines(1)
                  Text(`x${item.quantity}`).fontSize(12).fontColor(Const.TEXT_SUB)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text(Format.money(item.price * item.quantity)).fontSize(14)
              }.width('100%')
            }, (item: CartItem) => `${item.goodsId}_${item.quantity}`)
          }
          .width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // 金额明细
          Column({ space: 8 }) {
            Row() {
              Text('商品金额').fontSize(13).fontColor(Const.TEXT_SUB)
              Blank()
              Text(Format.money(this.totalAmount())).fontSize(13)
            }.width('100%')
            Row() {
              Text('运费').fontSize(13).fontColor(Const.TEXT_SUB)
              Blank()
              Text('免运费').fontSize(13).fontColor(Const.SUCCESS)
            }.width('100%')
            Divider().color(Const.DIVIDER)
            Row() {
              Text('合计').fontSize(14)
              Blank()
              Text(Format.money(this.totalAmount())).fontSize(16)
                .fontColor(Const.BRAND).fontWeight(FontWeight.Medium)
            }.width('100%')
          }
          .width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          Text('提示：本页面为课程 Demo，"支付"为模拟流程，不会产生真实交易。')
            .fontSize(11).fontColor(Const.TEXT_SUB).margin({ top: 4 })
        }.padding({ left: 16, right: 16, bottom: 80 })
      }.layoutWeight(1).scrollBar(BarState.Off)

      // 底部提交栏
      Row() {
        Text('合计 ').fontSize(13)
        Text(Format.money(this.totalAmount())).fontSize(18)
          .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
        Blank()
        Button(this.submitting ? '提交中...' : '提交订单')
          .height(42).borderRadius(21)
          .backgroundColor(Const.BRAND).fontColor(Color.White)
          .enabled(!this.submitting)
          .onClick(() => {
            this.submit()
          })
      }
      .width('100%').padding(16).backgroundColor(Const.CARD_BG)
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
