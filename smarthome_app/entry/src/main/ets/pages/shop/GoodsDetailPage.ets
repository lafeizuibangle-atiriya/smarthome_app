// pages/shop/GoodsDetailPage.ets —— 商品详情页（@Entry 子页面，手册 6.9）
// 【2026-09-29 充实】修复轮播图写死占位图的 bug（改用接口返回的 images URL）、
// 新增服务保障栏 / 标签行 / 卖点分段列表 / 同类推荐（复用 list 接口按分类过滤）。
import { router, promptAction } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { Goods } from '../../model/Shop'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'
import { TokenStore } from '../../common/TokenStore'
import { NumberStepper } from '../../view/NumberStepper'

interface GoodsParams {
  goodsId: number
}

@Entry
@Component
struct GoodsDetailPage {
  @State goods: Goods | null = null
  @State quantity: number = 1
  @State imageList: string[] = []
  @State imageIndex: number = 0      // 轮播当前页（右上角计数角标用）
  @State recommendList: Goods[] = [] // 同类推荐

  aboutToAppear() {
    const params = router.getParams() as GoodsParams
    this.load(params.goodsId)
  }

  async load(id: number) {
    const res = await ShopApi.goodsDetail(id)
    if (res.code === 200 && res.data) {
      this.goods = res.data
      // images 是 JSON 数组字符串，转成数组给 Swiper 用
      this.imageList = res.data.images ? JSON.parse(res.data.images) as string[] : []
      this.imageIndex = 0
      this.loadRecommend(this.goods.categoryId, this.goods.id)
    }
  }

  /** 同类推荐：拉同分类商品，排除自己，取前 4 个 */
  async loadRecommend(categoryId: number, selfId: number) {
    const res = await ShopApi.goodsList(categoryId, '')
    if (res.code === 200 && res.data) {
      const list: Goods[] = []
      for (const g of res.data) {
        if (g.id !== selfId && list.length < 4) {
          list.push(g)
        }
      }
      this.recommendList = list
    }
  }

  /** 详情分段：后端 detail 用『；』连接卖点，拆成一行一条渲染 */
  detailRows(detail: string): string[] {
    if (detail === '') {
      return ['暂无详情']
    }
    const rows: string[] = []
    for (const piece of detail.split('；')) {
      const text = piece.trim()
      if (text !== '') {
        rows.push(text)
      }
    }
    return rows.length > 0 ? rows : [detail]
  }

  /** 商品标签拆分（tags 逗号分隔） */
  tagRows(): string[] {
    if (this.goods === null || this.goods.tags === undefined || this.goods.tags === null) {
      return []
    }
    const tags: string[] = []
    for (const t of this.goods.tags.split(',')) {
      const text = t.trim()
      if (text !== '') {
        tags.push(text)
      }
    }
    return tags
  }

  /** 加入购物车（未登录先引导登录） */
  async addToCart() {
    if (!TokenStore.isLogin()) {
      router.pushUrl({ url: 'pages/login/LoginPage' })
      return
    }
    const res = await ShopApi.addCart(this.goods!.id, this.quantity)
    if (res.code === 200) {
      promptAction.showToast({ message: '已加入购物车' })
    }
  }

  /** 立即购买：跳到确认订单页，携带商品与数量 */
  buyNow() {
    if (!TokenStore.isLogin()) {
      router.pushUrl({ url: 'pages/login/LoginPage' })
      return
    }
    router.pushUrl({
      url: 'pages/shop/OrderConfirmPage',
      params: { goodsId: this.goods!.id, quantity: this.quantity }
    })
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('商品详情').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.goods !== null) {
        Scroll() {
          Column({ space: 12 }) {
            // ---------- 商品图轮播（修复：用接口 images 的 URL 渲染，不再写死占位图）----------
            Stack({ alignContent: Alignment.TopEnd }) {
              Swiper() {
                ForEach(this.imageList.length > 0 ? this.imageList : [this.goods!.cover],
                  (url: string) => {
                    Image(url).width('100%').height(280)
                      .backgroundColor('#F5F5F5').objectFit(ImageFit.Cover)
                        .alt($r('app.media.img_placeholder'))
                  }, (url: string) => url)
              }
              .height(280)
              .indicator(false)
              .loop(true)
              .onChange((index: number) => {
                this.imageIndex = index
              })

              Text(`${this.imageList.length > 0 ? this.imageIndex + 1 : 1}/${this.imageList.length > 0 ? this.imageList.length : 1}`)
                .fontSize(11).fontColor(Color.White)
                .backgroundColor('#66000000').borderRadius(10)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .margin({ top: 12, right: 12 })
            }.width('100%')

            // ---------- 价格与标题 ----------
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text(Format.money(this.goods!.price)).fontSize(22)
                  .fontWeight(FontWeight.Medium).fontColor(Const.BRAND)
                if ((this.goods!.originPrice ?? 0) > this.goods!.price) {
                  Text(Format.money(this.goods!.originPrice!)).fontSize(13)
                    .fontColor(Const.TEXT_SUB)
                    .decoration({ type: TextDecorationType.LineThrough })
                }
                Blank()
                Text(`已售 ${this.goods!.sales}`).fontSize(12).fontColor(Const.TEXT_SUB)
              }.width('100%')
              Text(this.goods!.name).fontSize(16).fontWeight(FontWeight.Medium)
              // 标签行
              if (this.tagRows().length > 0) {
                Row({ space: 6 }) {
                  ForEach(this.tagRows(), (tag: string) => {
                    Text(tag).fontSize(11).fontColor(Const.BRAND)
                      .backgroundColor('#FFF3E8')
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(4)
                  }, (tag: string) => tag)
                }
              }
              Text(`库存 ${this.goods!.stock} 件`).fontSize(12).fontColor(Const.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start).width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 服务保障 ----------
            Row({ space: 16 }) {
              Text('✓ 官方正品').fontSize(12).fontColor(Const.TEXT_SUB)
              Text('✓ 7天无理由').fontSize(12).fontColor(Const.TEXT_SUB)
              Text('✓ 全国包邮').fontSize(12).fontColor(Const.TEXT_SUB)
              Blank()
            }
            .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 数量选择 ----------
            Row() {
              Text('购买数量').fontSize(14)
              Blank()
              NumberStepper({
                value: this.quantity,
                min: 1,
                max: this.goods!.stock,
                onValueChange: (value: number) => {
                  this.quantity = value
                }
              })
            }
            .width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 图文详情（卖点分段列表）----------
            Column({ space: 8 }) {
              Text('商品详情').fontSize(14).fontWeight(FontWeight.Medium)
              ForEach(this.detailRows(this.goods!.detail ?? ''), (row: string) => {
                Row({ space: 8 }) {
                  Circle({ width: 4, height: 4 }).fill(Const.BRAND)
                  Text(row).fontSize(13).fontColor(Const.TEXT_SUB).lineHeight(22)
                    .layoutWeight(1)
                }.alignItems(VerticalAlign.Top).width('100%')
              }, (row: string, index: number) => `${index}_${row}`)
            }
            .alignItems(HorizontalAlign.Start).width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 同类推荐 ----------
            if (this.recommendList.length > 0) {
              Column({ space: 10 }) {
                Text('看了又看').fontSize(14).fontWeight(FontWeight.Medium)
                Row({ space: 10 }) {
                  ForEach(this.recommendList, (goods: Goods) => {
                    Column({ space: 4 }) {
                      Image(goods.cover).width(76).height(76)
                        .borderRadius(8).backgroundColor('#F5F5F5')
                        .objectFit(ImageFit.Cover).alt($r('app.media.img_placeholder'))
                      Text(goods.name).fontSize(11).maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(Format.money(goods.price)).fontSize(12)
                        .fontColor(Const.BRAND).fontWeight(FontWeight.Medium)
                    }
                    .width('25%')
                    .onClick(() => {
                      router.replaceUrl({
                        url: 'pages/shop/GoodsDetailPage',
                        params: { goodsId: goods.id }
                      })
                    })
                  }, (goods: Goods) => `${goods.id}_${goods.sales}`)
                }.width('100%')
              }
              .alignItems(HorizontalAlign.Start).width('100%').padding(16)
              .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
            }

            Text('提示：本页面为课程 Demo，购买流程为模拟演示，不会产生真实交易。')
              .fontSize(11).fontColor(Const.TEXT_SUB)
          }.padding({ left: 16, right: 16, bottom: 80 })
        }.layoutWeight(1).scrollBar(BarState.Off)

        // ---------- 底部操作栏 ----------
        Row({ space: 12 }) {
          Button('加入购物车')
            .layoutWeight(1).height(44).borderRadius(22)
            .backgroundColor(Const.CARD_BG).fontColor(Const.BRAND)
            .border({ width: 1, color: Const.BRAND })
            .onClick(() => {
              this.addToCart()
            })
          Button('立即购买')
            .layoutWeight(1).height(44).borderRadius(22)
            .backgroundColor(Const.BRAND).fontColor(Color.White)
            .onClick(() => {
              this.buyNow()
            })
        }
        .width('100%').padding(16).backgroundColor(Const.CARD_BG)
      } else {
        Text('加载中...').fontSize(14).fontColor(Const.TEXT_SUB).margin({ top: 100 })
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
