// pages/shop/CartPage.ets —— 购物车页（@Entry 子页面，手册 6.11）
// 商品行（勾选、图、名、价、数量步进器、长按删除）；底部合计金额 + 结算按钮；空态。
import { router, promptAction } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { CartItem } from '../../model/Shop'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'
import { TokenStore } from '../../common/TokenStore'
import { NumberStepper } from '../../view/NumberStepper'
import { EmptyView } from '../../view/EmptyView'

@Entry
@Component
struct CartPage {
  @State items: CartItem[] = []

  aboutToAppear() {
    this.load()
  }

  async load() {
    if (!TokenStore.isLogin()) {
      promptAction.showToast({ message: '请先登录' })
      return
    }
    const res = await ShopApi.cartList()
    if (res.code === 200 && res.data) {
      // checked 是前端本地状态，默认全选
      this.items = res.data.map((item: CartItem) => {
        item.checked = true
        return item
      })
    }
  }

  /** 修改数量：先改本地再同步后端，体验更顺滑 */
  async changeQuantity(item: CartItem, quantity: number) {
    item.quantity = quantity
    this.items = this.items.slice()          // 重新赋值触发 UI 刷新
    await ShopApi.updateCart(item.id, quantity)
  }

  async removeItem(item: CartItem) {
    const res = await ShopApi.removeCart(item.id)
    if (res.code === 200) {
      promptAction.showToast({ message: '已删除' })
      this.load()
    }
  }

  /** 已勾选商品总价 */
  totalAmount(): number {
    let total: number = 0
    this.items.forEach((item: CartItem) => {
      if (item.checked) {
        total += item.price * item.quantity
      }
    })
    return total
  }

  selectedCount(): number {
    return this.items.filter((item: CartItem) => item.checked).length
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('购物车').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.items.length === 0) {
        EmptyView({ text: '购物车还是空的', buttonText: '去逛逛',
          onAction: () => {
            router.back()
          } })
      } else {
        List({ space: Const.CARD_GAP }) {
          ForEach(this.items, (item: CartItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Checkbox({ name: item.id.toString(), group: 'cart' })
                  .select(item.checked)
                  .selectedColor(Const.BRAND)
                  .onChange((checked: boolean) => {
                    item.checked = checked
                    this.items = this.items.slice()
                  })
                Image(item.goodsCover).width(72).height(72)
                  .borderRadius(8).backgroundColor('#F5F5F5').objectFit(ImageFit.Cover)
                  .alt($r('app.media.img_placeholder'))
                Column({ space: 6 }) {
                  Text(item.goodsName).fontSize(14).maxLines(2)
                  Row() {
                    Text(Format.money(item.price)).fontSize(15)
                      .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
                    Blank()
                    NumberStepper({
                      value: item.quantity, min: 1,
                      onValueChange: (value: number) => {
                        this.changeQuantity(item, value)
                      }
                    })
                  }.width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
              .padding(12).backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
              // 长按删除
              .gesture(LongPressGesture().onAction(() => {
                this.removeItem(item)
              }))
            }
          }, (item: CartItem) => `${item.id}_${item.quantity}_${item.checked ? 1 : 0}`)
        }.layoutWeight(1).scrollBar(BarState.Off)

        // 底部结算栏
        Row() {
          Text(`已选 ${this.selectedCount()} 件`).fontSize(13).fontColor(Const.TEXT_SUB)
          Blank()
          Text('合计 ').fontSize(13)
          Text(Format.money(this.totalAmount())).fontSize(18)
            .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
          Button('结算')
            .height(40).borderRadius(20).margin({ left: 12 })
            .backgroundColor(this.selectedCount() > 0 ? Const.BRAND : '#CCCCCC')
            .fontColor(Color.White)
            .enabled(this.selectedCount() > 0)
            .onClick(() => {
              const selected: CartItem[] = this.items.filter((item: CartItem) => item.checked)
              // 用 JSON 字符串传数组（router 参数只支持基础类型）
              router.pushUrl({
                url: 'pages/shop/OrderConfirmPage',
                params: { cartItems: JSON.stringify(selected) }
              })
            })
        }
        .width('100%').padding(16).backgroundColor(Const.CARD_BG)
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
