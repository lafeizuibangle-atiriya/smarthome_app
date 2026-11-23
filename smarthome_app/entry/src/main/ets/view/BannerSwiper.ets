// view/BannerSwiper.ets —— 轮播图组件（首页 / 商城共用，自研实现）
// 数据来自公开接口 /api/banner/list?position=home|shop（ShopApi.bannerList()）。
// 【2026-09-29】banner.image_url 已换成 unsplash 网图外链（完整 https URL），
// Image 直接渲染 URL；空数据时回退本地占位图。
// 【注意】组件属性名不能叫 position/enabled 等 —— 会和 ArkUI 内置属性方法冲突。
import { ShopApi } from '../api/ShopApi'
import { BannerItem } from '../model/Shop'
import { Const } from '../common/Const'

@Component
export struct BannerSwiper {
  /** 轮播位：home 主页 / shop 商城（对应后端 banner.position） */
  @Prop bannerPos: string = 'shop'
  /** 无数据时是否隐藏整个组件（商城页传 false，避免留一块空白） */
  @Prop hideWhenEmpty: boolean = false
  @State urls: string[] = []

  aboutToAppear() {
    this.load()
  }

  async load() {
    const res = await ShopApi.bannerList(this.bannerPos)
    if (res.code === 200 && res.data) {
      this.urls = res.data.map((banner: BannerItem) => {
        const url: string = banner.imageUrl ?? ''
        return url
      })
    }
  }

  build() {
    if (this.urls.length > 0 || !this.hideWhenEmpty) {
      Swiper() {
        ForEach(this.urls.length > 0 ? this.urls : ['banner'],
          (url: string) => {
            if (url.startsWith('http')) {
              Image(url).width('100%').height(140)
                .borderRadius(Const.CARD_RADIUS).objectFit(ImageFit.Cover)
            } else {
              Image($r('app.media.img_banner')).width('100%').height(140)
                .borderRadius(Const.CARD_RADIUS).objectFit(ImageFit.Cover)
            }
          }, (url: string) => url)
      }
      .height(140)
      .autoPlay(true)
      .interval(3000)
      .indicator(new DotIndicator().color('#FFFFFFAA').selectedColor(Const.BRAND))
    }
  }
}
