// view/GoodsCard.ets —— 商品卡片（瀑布流两列，商城页用）
import { router } from '@kit.ArkUI'
import { Goods } from '../model/Shop'
import { Const } from '../common/Const'
import { Format } from '../common/Format'

@Component
export struct GoodsCard {
  @Prop goods: Goods

  build() {
    Column({ space: 6 }) {
      // 2026-09-29：改用数据库里的商品封面（unsplash 网图外链），不再写死占位图
      Image(this.goods.cover).width('100%').height(120)
        .borderRadius(10).backgroundColor('#F5F5F5').objectFit(ImageFit.Cover)
        .alt($r('app.media.img_placeholder'))
      Text(this.goods.name).fontSize(13).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Row({ space: 6 }) {
        Text(Format.money(this.goods.price)).fontSize(15)
          .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
        Text(`已售 ${this.goods.sales}`).fontSize(11).fontColor(Const.TEXT_SUB)
      }.width('100%')
    }
    .padding(10).backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
    .onClick(() => {
      router.pushUrl({ url: 'pages/shop/GoodsDetailPage', params: { goodsId: this.goods.id } })
    })
  }
}
