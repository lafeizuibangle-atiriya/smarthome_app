// pages/product/ProductDetailPage.ets —— 产品详情页（@Entry 子页面，手册 6.7）
// 【2026-09-29 充实】主图改用数据库 cover 网图；规格参数 JSON 解析成一行一条，不再一坨展示。
import { router } from '@kit.ArkUI'
import { ProductApi } from '../../api/ProductApi'
import { Product } from '../../model/Product'
import { Const } from '../../common/Const'

interface ProductParams {
  productId: number
}

@Entry
@Component
struct ProductDetailPage {
  @State product: Product | null = null

  aboutToAppear() {
    const params = router.getParams() as ProductParams
    this.load(params.productId)
  }

  async load(id: number) {
    const res = await ProductApi.detail(id)
    if (res.code === 200 && res.data) {
      this.product = res.data
    }
  }

  /** 规格参数 JSON 字符串解析为行数组（解析失败返回空数组） */
  specRows(specs: string): string[] {
    if (specs === '' || specs === null) {
      return []
    }
    try {
      return JSON.parse(specs) as string[]
    } catch (e) {
      return []
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('产品详情').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.product !== null) {
        Scroll() {
          Column({ space: 12 }) {
            // 产品主图（2026-09-29：cover 是 unsplash 网图外链）
            Image(this.product!.cover).width('100%').height(240)
              .borderRadius(12).backgroundColor('#F0F0F0').objectFit(ImageFit.Cover)
              .alt($r('app.media.img_placeholder'))

            Column({ space: 8 }) {
              Text(this.product!.name).fontSize(20).fontWeight(FontWeight.Medium)
              Text(this.product!.slogan).fontSize(13).fontColor(Const.BRAND)
              Text(this.product!.description ?? '').fontSize(13).lineHeight(22)
                .fontColor(Const.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start).width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // 规格参数（JSON 解析为一行一条）
            if (this.specRows(this.product!.specs ?? '').length > 0) {
              Column({ space: 8 }) {
                Text('规格参数').fontSize(14).fontWeight(FontWeight.Medium)
                ForEach(this.specRows(this.product!.specs ?? ''), (row: string) => {
                  Row({ space: 8 }) {
                    Circle({ width: 4, height: 4 }).fill(Const.BRAND)
                    Text(row).fontSize(13).fontColor(Const.TEXT_SUB).layoutWeight(1)
                  }.alignItems(VerticalAlign.Top).width('100%')
                }, (row: string, index: number) => `${index}_${row}`)
              }
              .alignItems(HorizontalAlign.Start).width('100%').padding(16)
              .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
            }

            // 标签
            if ((this.product!.tags ?? '') !== '') {
              Row({ space: 6 }) {
                ForEach((this.product!.tags ?? '').split(','), (tag: string) => {
                  Text(tag.trim()).fontSize(11).fontColor(Const.BRAND)
                    .backgroundColor('#FFF3E8')
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(4)
                }, (tag: string) => tag)
              }.width('100%')
            }

            // 去商城：带上关联商品 id，可直接打开对应商品详情
            if ((this.product!.relatedGoodsId ?? 0) > 0) {
              Button('去商城看看')
                .width('100%').height(44).borderRadius(22)
                .backgroundColor(Const.BRAND).fontColor(Color.White)
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/shop/GoodsDetailPage',
                    params: { goodsId: this.product!.relatedGoodsId }
                  })
                })
            }
          }.padding({ left: 16, right: 16, bottom: 16 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      } else {
        Text('加载中...').fontSize(14).fontColor(Const.TEXT_SUB).margin({ top: 100 })
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
