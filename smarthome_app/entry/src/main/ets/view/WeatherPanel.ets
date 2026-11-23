// view/WeatherPanel.ets —— 今日天气面板（和风天气，后端代理）
// 数据源：GET /api/weather/now（全部字段透传，UI 依数据而定）
// 交互：点城市名弹城市清单切换；每 60 分钟自动刷新；
//       【未登录不发请求】；【Tabs 子页切走要停表】（visible 由 HomePage 传入）。
import { promptAction } from '@kit.ArkUI'
import { WeatherApi } from '../api/WeatherApi'
import { WeatherNow, WeatherCity } from '../model/Weather'
import { Const } from '../common/Const'
import { TokenStore } from '../common/TokenStore'

/** 指标格（title/value/unit 三元组；单独声明 interface 避免裸字面量） */
interface MetricItem {
  title: string
  value: string
  unit: string
}

@Component
export struct WeatherPanel {
  @State weather: WeatherNow | null = null
  @State cities: WeatherCity[] = []
  @State currentCityId: string = ''          // 空串 = 后端默认城市（南昌）
  @State currentCityName: string = '南昌'
  @State sheetShow: boolean = false          // 城市切换弹层
  @State loading: boolean = false
  @State loadFailed: boolean = false        // 首次加载失败标记：显示"点击重试"，不能永远卡"获取中"

  /** 首页是否可见：切走 Tab 时停掉小时定时器（Tabs 子页不销毁的坑） */
  @Prop @Watch('onVisibleChange') visible: boolean = false

  private timerId: number = -1
  private retryTimerId: number = -1         // 首次失败后的 30 秒兜底重试

  /** 60 分钟自动刷新（需求明确：每隔一个小时获取一次） */
  private static readonly REFRESH_MS: number = 60 * 60 * 1000

  /** 首次加载失败后的重试间隔 */
  private static readonly RETRY_MS: number = 30 * 1000

  onVisibleChange() {
    this.sync()
  }

  aboutToAppear() {
    this.sync()
  }

  aboutToDisappear() {
    this.stopTimer()
  }

  /** 按「可见性 + 登录态」决定要不要拉数据、要不要起定时器 */
  async sync() {
    if (!this.visible || !TokenStore.isLogin()) {
      this.stopTimer()
      return
    }
    await this.loadCitiesOnce()
    await this.load()
    this.startTimer()
  }

  /** 城市清单只拉一次（固定数据，后端内置） */
  private citiesLoaded: boolean = false

  private async loadCitiesOnce() {
    if (this.citiesLoaded) {
      return
    }
    const res = await WeatherApi.cities()
    if (res.code === 200 && res.data) {
      this.cities = res.data
      this.citiesLoaded = true
    }
  }

  startTimer() {
    if (this.timerId !== -1) {
      return
    }
    this.timerId = setInterval(() => {
      if (TokenStore.isLogin()) {
        this.load()
      }
    }, WeatherPanel.REFRESH_MS)
  }

  stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.stopRetryTimer()
  }

  async load() {
    if (this.loading) {
      return        // 防重入
    }
    this.loading = true
    try {
      const res = await WeatherApi.now(this.currentCityId)
      if (res.code === 200 && res.data) {
        this.weather = res.data
        this.currentCityName = res.data.cityName
        this.loadFailed = false
        this.stopRetryTimer()      // 拿到数据就停掉兜底重试
      } else if (this.weather === null) {
        // 首次加载失败（比如启动时后端还没就绪）：标记失败 + 30 秒后自动重试，
        // 不能静默等到 60 分钟的定时器——那会让人以为天气坏了
        this.loadFailed = true
        this.scheduleRetry()
      }
      // 失败不弹窗：天气是辅助信息（手册 4.3.2 节流原则），靠"点击重试"+自动重试兜底
    } finally {
      this.loading = false
    }
  }

  /** 首次加载失败后的兜底：每 30 秒重试，直到成功（只针对 weather 还是空的情况） */
  private scheduleRetry() {
    if (this.retryTimerId !== -1 || this.weather !== null) {
      return
    }
    this.retryTimerId = setInterval(() => {
      this.load()
    }, WeatherPanel.RETRY_MS)
  }

  private stopRetryTimer() {
    if (this.retryTimerId !== -1) {
      clearInterval(this.retryTimerId)
      this.retryTimerId = -1
    }
  }

  /** 切换城市：用户主动操作，成功后明确提示 */
  async switchCity(city: WeatherCity) {
    this.sheetShow = false
    if (city.id === this.currentCityId) {
      return
    }
    this.currentCityId = city.id
    await this.load()
    if (this.weather !== null) {
      promptAction.showToast({ message: `已切换到${city.name}` })
    }
  }

  /** 和风 icon 代码 → emoji（按代码段映射，覆盖晴/云/雨/雪/雾/雷） */
  private weatherEmoji(): string {
    if (this.weather === null) {
      return '🌤'
    }
    const code: number = parseInt(this.weather.icon)
    if (code >= 100 && code <= 103) {
      return '☀️'          // 晴
    }
    if (code >= 104 && code <= 1030 || (code >= 1000 && code <= 1003)) {
      return '⛅'          // 多云/阴
    }
    if (code >= 300 && code <= 399) {
      return code >= 302 && code <= 304 ? '⛈️' : '🌧️'
    }
    if (code >= 400 && code <= 499) {
      return '❄️'
    }
    if (code >= 500 && code <= 515) {
      return '🌫️'          // 雾/霾
    }
    return '🌤'
  }

  /** 格式化更新时间：2026-09-23T01:40+08:00 → 09-23 01:40 */
  private shortTime(raw: string): string {
    if (raw.length < 16) {
      return raw
    }
    return raw.substring(5, 16).replace('T', ' ')
  }

  /** 指标格标题：数据缺失显示 -- */
  private val(v: string): string {
    return (v === undefined || v === null || v.length === 0) ? '--' : v
  }

  /**
   * 8 项详尽指标（按 API 实际返回字段排布）。
   * 用方法每次现算 + ForEach 渲染：避免 @Builder 按值传参的"一次性快照"问题
   * （手册踩坑：状态变了 Builder 不刷新）。
   */
  private metrics(): MetricItem[] {
    const w: WeatherNow | null = this.weather
    const windUnit: string =
      w !== null && w.windScale !== undefined && w.windScale.length > 0
        ? ` ${w.windScale}级` : ''
    const list: MetricItem[] = [
      { title: '湿度', value: this.val(w?.humidity ?? ''), unit: '%' },
      { title: '风向', value: this.val(w?.windDir ?? ''), unit: windUnit },
      { title: '风速', value: this.val(w?.windSpeed ?? ''), unit: 'km/h' },
      { title: '降水量', value: this.val(w?.precip ?? ''), unit: 'mm' },
      { title: '气压', value: this.val(w?.pressure ?? ''), unit: 'hPa' },
      { title: '能见度', value: this.val(w?.vis ?? ''), unit: 'km' },
      { title: '云量', value: this.val(w?.cloud ?? ''), unit: '%' },
      { title: '露点', value: this.val(w?.dew ?? ''), unit: '℃' }
    ]
    return list
  }

  build() {
    Column({ space: 10 }) {
      // ---------- 第一行：城市 + 更新时间 ----------
      Row() {
        Text(`${this.currentCityName} ▾`)
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .onClick(() => {
            this.sheetShow = true
          })
        Blank()
        Text(`更新 ${this.weather === null ? '--' : this.shortTime(this.weather.updateTime)}`)
          .fontSize(10).fontColor('rgba(255,255,255,0.7)')
      }.width('100%')

      // ---------- 第二行：大温度 + 天气现象 ----------
      Row({ space: 12 }) {
        Text(this.weatherEmoji()).fontSize(40)
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Text(this.weather === null ? '--' : this.weather.temp)
              .fontSize(38).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('℃').fontSize(18).fontColor('rgba(255,255,255,0.85)')
              .margin({ top: 10 })
          }.alignItems(VerticalAlign.Top)
          Text(this.weather === null
            ? (this.loadFailed ? '获取失败，点击重试' : '获取中...')
            : `${this.weather.text} · 体感 ${this.val(this.weather.feelsLike)}℃`)
            .fontSize(12).fontColor('rgba(255,255,255,0.85)')
            .onClick(() => {
              if (this.weather === null) {
                this.load()
              }
            })
        }.alignItems(HorizontalAlign.Start)
        Blank()
      }.width('100%')

      Divider().color('rgba(255,255,255,0.25)')

      // ---------- 第三行：8 项详尽指标（按 API 实际返回字段排布）----------
      // 【key 必须含 value】数据一变 key 就变，组件才用新数据重建（手册踩坑 14）
      Grid() {
        ForEach(this.metrics(), (item: MetricItem, index: number) => {
          GridItem() {
            Column({ space: 2 }) {
              Text(item.title).fontSize(11).fontColor('rgba(255,255,255,0.7)')
              Text(`${item.value}${item.unit}`)
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
        }, (item: MetricItem, index: number) => `${index}_${item.value}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .height(84)

      // ---------- 观测时间脚注 ----------
      Text(`观测时间 ${this.weather === null ? '--' : this.shortTime(this.weather.obsTime)}`)
        .fontSize(10).fontColor('rgba(255,255,255,0.6)')
        .width('100%')
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding(16)
    // 米家风格：天气卡 = 天空蓝渐变（主色改为米家绿后，信息类卡片统一用蓝）
    .linearGradient({
      angle: 160,
      colors: [['#5E93D6', 0], ['#9CC3EE', 1]]
    })
    .borderRadius(Const.CARD_RADIUS)
    // 城市切换弹层（半模态）
    .bindSheet(this.sheetShow, this.citySheet(), {
      height: 420,
      showClose: true
    })
  }

  /** 城市清单弹层内容 */
  @Builder
  citySheet() {
    Column() {
      Text('选择城市')
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
        .width('100%').padding({ top: 8, bottom: 8, left: 20 })
      List({ space: 4 }) {
      ForEach(this.cities, (city: WeatherCity, index: number) => {
        ListItem() {
          Row() {
            Text(city.name)
              .fontSize(15)
              .fontColor(city.id === this.currentCityId ? Const.BRAND : Const.TEXT_MAIN)
              .fontWeight(city.id === this.currentCityId ? FontWeight.Bold : FontWeight.Normal)
            Blank()
            if (city.id === this.currentCityId) {
              Text('✓').fontSize(15).fontColor(Const.BRAND)
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 13, bottom: 13 })
          .onClick(() => {
            this.switchCity(city)
          })
        }
      }, (city: WeatherCity, index: number) => `${city.id}_${index}`)
    }
    .width('100%')
    .scrollBar(BarState.Auto)
    .layoutWeight(1)
    }
    .width('100%').height('100%')
  }
}
