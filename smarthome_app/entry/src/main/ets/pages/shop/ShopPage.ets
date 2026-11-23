// pages/shop/ShopPage.ets —— 底部 Tab·商城（@Component，由 Index 内嵌承载，不是 @Entry！）
// 手册 6.8：顶部搜索 + 购物车角标 + 轮播 Banner + 分类金刚区 + 商品两列网格。
// 【2026-09-29 重做】搜索框绑定 onChange(500ms 防抖)/onSubmit、金刚区带图标可点按分类筛选、
// 分类「全部」高亮切换、结果区标题随筛选变化 —— 之前搜索框和金刚区都是纯摆设。
import { router } from '@kit.ArkUI'
import { ShopApi } from '../../api/ShopApi'
import { Goods, Category } from '../../model/Shop'
import { Const } from '../../common/Const'
import { Format } from '../../common/Format'
import { TokenStore } from '../../common/TokenStore'
import { GoodsCard } from '../../view/GoodsCard'
import { BannerSwiper } from '../../view/BannerSwiper'
import { EmptyView } from '../../view/EmptyView'

@Component
export struct ShopPage {
  @State categories: Category[] = []
  @State goodsList: Goods[] = []
  @State cartCount: number = 0        // 购物车角标数量
  @State currentCategoryId: number = 0  // 0 = 全部分类
  @State searchText: string = ''        // 搜索框内容
  @State keyword: string = ''           // 生效中的搜索关键字
  @State searching: boolean = false     // 搜索 loading
  private debounceTimer: number = -1    // 防抖定时器

  aboutToAppear() {
    this.loadCategories()
    this.loadGoods()
    this.loadCartCount()
  }

  async loadCategories() {
    const cateRes = await ShopApi.categories()
    if (cateRes.code === 200 && cateRes.data) {
      this.categories = cateRes.data
    }
  }

  async loadGoods() {
    const goodsRes = await ShopApi.goodsList(this.currentCategoryId, this.keyword)
    if (goodsRes.code === 200 && goodsRes.data) {
      this.goodsList = goodsRes.data
    }
  }

  /** 购物车数量：未登录时不请求，避免多余的 401（踩坑 13） */
  async loadCartCount() {
    if (!TokenStore.isLogin()) {
      return
    }
    const cartRes = await ShopApi.cartList()
    if (cartRes.code === 200 && cartRes.data) {
      this.cartCount = cartRes.data.length
    }
  }

  /** 切换分类：再点一次取消回到全部 */
  selectCategory(id: number) {
    this.currentCategoryId = (this.currentCategoryId === id) ? 0 : id
    this.loadGoods()
  }

  /** 搜索输入防抖：停顿 500ms 才真正请求，避免每敲一个字就打一次接口 */
  onSearchInput(value: string) {
    this.searchText = value
    if (this.debounceTimer !== -1) {
      clearTimeout(this.debounceTimer)
    }
    this.debounceTimer = setTimeout(() => {
      this.keyword = this.searchText
      this.loadGoods()
    }, 500)
  }

  /** 清空搜索 */
  clearSearch() {
    if (this.debounceTimer !== -1) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = -1
    }
    this.searchText = ''
    this.keyword = ''
    this.loadGoods()
  }

  /** 金刚区分类图标（按分类名映射，兜底 🔘） */
  categoryIcon(name: string): string {
    if (name.indexOf('照明') >= 0) {
      return '💡'
    }
    if (name.indexOf('安防') >= 0) {
      return '🛡️'
    }
    if (name.indexOf('环境') >= 0) {
      return '🌿'
    }
    if (name.indexOf('厨房') >= 0) {
      return '🍳'
    }
    if (name.indexOf('操控') >= 0) {
      return '🎛️'
    }
    if (name.indexOf('清洁') >= 0) {
      return '🧹'
    }
    return '🔘'
  }

  build() {
    Column() {
      // ---------- 顶部：搜索 + 购物车 ----------
      Row({ space: 12 }) {
        Search({ placeholder: '搜索商品名 / 功能 / 标签' })
          .layoutWeight(1).height(38)
          .onChange((value: string) => {
            this.onSearchInput(value)
          })
          .onSubmit(() => {
            if (this.debounceTimer !== -1) {
              clearTimeout(this.debounceTimer)
              this.debounceTimer = -1
            }
            this.keyword = this.searchText
            this.loadGoods()
          })
          .onClick(() => {
            // 点击搜索框即视为发起当前关键字搜索（点放大镜的快捷路径）
            if (this.searchText !== this.keyword && this.searchText !== '') {
              this.keyword = this.searchText
              this.loadGoods()
            }
          })
        Row() {
          Image($r('app.media.ic_cart')).width(24).height(24)
            .fillColor(Const.TEXT_MAIN)
          if (this.cartCount > 0) {
            Text(this.cartCount.toString()).fontSize(10).fontColor(Color.White)
              .backgroundColor(Const.BRAND).borderRadius(8)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .margin({ left: -8, top: -12 })
          }
        }.onClick(() => {
          router.pushUrl({ url: 'pages/shop/CartPage' })
        })
      }.width('100%').padding({ bottom: 12 })

      Scroll() {
        Column({ space: 12 }) {
          // ---------- 轮播 Banner（公开接口，组件内部自己拉数据）----------
          BannerSwiper({ bannerPos: 'shop', hideWhenEmpty: false })

          // ---------- 分类金刚区：全部 + 6 分类，可点筛选、选中高亮 ----------
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.allCategoryItems(), (item: Category) => {
              Column({ space: 6 }) {
                Stack() {
                  Circle({ width: 44, height: 44 })
                    .fill(item.id === this.currentCategoryId ? Const.BRAND : '#FFF3E8')
                  Text(item.id === 0 ? '🛍️' : this.categoryIcon(item.name))
                    .fontSize(20)
                }
                Text(item.name).fontSize(11)
                  .fontColor(item.id === this.currentCategoryId ? Const.BRAND : Const.TEXT_MAIN)
                  .fontWeight(item.id === this.currentCategoryId ? FontWeight.Medium : FontWeight.Normal)
              }.width('20%').margin({ bottom: 12 })
              .onClick(() => {
                if (item.id === 0) {
                  this.clearSearch()
                  this.currentCategoryId = 0
                  this.loadGoods()
                } else {
                  this.selectCategory(item.id)
                }
              })
            }, (item: Category) => `${item.id}_${item.name}_${item.id === this.currentCategoryId}`)
          }
          .width('100%').padding(12)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // ---------- 商品两列网格：标题随筛选状态变化 ----------
          Row({ space: 8 }) {
            if (this.keyword !== '') {
              Text(`"${this.keyword}" 的搜索结果`).fontSize(14).fontWeight(FontWeight.Medium)
            } else if (this.currentCategoryId > 0) {
              Text(this.currentCategoryName()).fontSize(14).fontWeight(FontWeight.Medium)
            } else {
              Text('为你推荐').fontSize(14).fontWeight(FontWeight.Medium)
            }
            if (this.keyword !== '' || this.currentCategoryId > 0) {
              Text('清除筛选').fontSize(12).fontColor(Const.TEXT_SUB)
                .onClick(() => {
                  this.clearSearch()
                  this.currentCategoryId = 0
                  this.loadGoods()
                })
            }
            Blank()
            Text(`${this.goodsList.length} 件`).fontSize(12).fontColor(Const.TEXT_SUB)
          }.width('100%').margin({ top: 4 })

          if (this.goodsList.length === 0) {
            EmptyView({ text: this.keyword !== '' ? '没找到相关商品，换个关键词试试' : '商品上架中，敬请期待' })
          } else {
            Grid() {
              ForEach(this.goodsList, (goods: Goods) => {
                GridItem() {
                  GoodsCard({ goods: goods })
                }
              }, (goods: Goods) => `${goods.id}_${goods.stock}_${goods.sales}`)
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(Const.CARD_GAP).rowsGap(Const.CARD_GAP)
            .height(Math.ceil(this.goodsList.length / 2) * 230)
          }
        }.padding({ bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').padding(16).backgroundColor(Const.PAGE_BG)
  }

  /** 金刚区数据源：「全部」+ 后端分类 */
  allCategoryItems(): Category[] {
    const all: Category = { id: 0, name: '全部' }
    return [all].concat(this.categories)
  }

  currentCategoryName(): string {
    for (const c of this.categories) {
      if (c.id === this.currentCategoryId) {
        return c.name
      }
    }
    return '分类商品'
  }
}
