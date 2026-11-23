// pages/product/ProductPage.ets —— 底部 Tab·产品（@Component，由 Index 内嵌承载，不是 @Entry！）
// 手册 6.6：顶部搜索框 + 分类 Tab + 产品卡片列表；点击进 ProductDetailPage。
import { router } from '@kit.ArkUI'
import { ProductApi } from '../../api/ProductApi'
import { Product } from '../../model/Product'
import { Const } from '../../common/Const'
import { EmptyView } from '../../view/EmptyView'

@Component
export struct ProductPage {
  @State categories: string[] = ['全部']
  @State currentCategory: string = '全部'
  @State products: Product[] = []
  @State keyword: string = ''

  aboutToAppear() {
    this.loadCategories()
    this.loadProducts()
  }

  async loadCategories() {
    const res = await ProductApi.categories()
    if (res.code === 200 && res.data) {
      this.categories = ['全部'].concat(res.data)     // 头部加"全部"选项
    }
  }

  async loadProducts() {
    const category: string = this.currentCategory === '全部' ? '' : this.currentCategory
    const res = await ProductApi.list(category, this.keyword)
    if (res.code === 200 && res.data) {
      this.products = res.data
    }
  }

  build() {
    Column() {
      // 搜索框
      Search({ placeholder: '搜索产品' })
        .width('100%').height(40)
        .margin({ bottom: 12 })
        .onChange((value: string) => {
          this.keyword = value
        })
        .onSubmit(() => {
          this.loadProducts()
        })

      // 分类 Tab（横向滚动）
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.categories, (category: string) => {
            Text(category).fontSize(13)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(15)
              .backgroundColor(category === this.currentCategory ? Const.BRAND : Const.CARD_BG)
              .fontColor(category === this.currentCategory ? Color.White : Const.TEXT_MAIN)
              .onClick(() => {
                this.currentCategory = category
                this.loadProducts()
              })
          }, (category: string) => category)
        }
      }.scrollable(ScrollDirection.Horizontal).width('100%').margin({ bottom: 12 })

      // 产品列表
      if (this.products.length === 0) {
        EmptyView({ text: '没有找到相关产品' })
      } else {
        List({ space: Const.CARD_GAP }) {
          ForEach(this.products, (product: Product) => {
            ListItem() {
              Row({ space: 12 }) {
                // 产品图（2026-09-29：改用数据库 cover 网图外链，不再写死占位图）
                Image(product.cover).width(80).height(80)
                  .borderRadius(10).backgroundColor('#F0F0F0').objectFit(ImageFit.Cover)
                  .alt($r('app.media.img_placeholder'))
                Column({ space: 6 }) {
                  Text(product.name).fontSize(15).fontWeight(FontWeight.Medium).maxLines(1)
                  Text(product.slogan).fontSize(12).fontColor(Const.TEXT_SUB).maxLines(2)
                  Text(product.tags ?? '').fontSize(11).fontColor(Const.BRAND)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }
              .padding(14).backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/product/ProductDetailPage', params: { productId: product.id }
                })
              })
            }
          }, (product: Product) => `${product.id}_${product.name}`)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').padding(16).backgroundColor(Const.PAGE_BG)
  }
}
