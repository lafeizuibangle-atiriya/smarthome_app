// pages/home/HomePage.ets —— 底部 Tab·主页（@Component，由 Index 内嵌承载，不是 @Entry！）
// 天气面板 + 全屋模式卡 + 房间 Tab + 设备网格。
// 1 秒轮询；【未登录不发请求、不起轮询】；【切走 Tab 停轮询】。
import { router, promptAction } from '@kit.ArkUI'
import { DeviceApi } from '../../api/DeviceApi'
import { Device, Room } from '../../model/Device'
import { Const } from '../../common/Const'
import { TokenStore } from '../../common/TokenStore'
import { DeviceCard } from '../../view/DeviceCard'
import { WeatherPanel } from '../../view/WeatherPanel'
import { EmptyView } from '../../view/EmptyView'

@Component
export struct HomePage {
  @State homeName: string = '我的家'
  @State rooms: Room[] = []
  @State currentRoomIndex: number = 0
  @State devices: Device[] = []
  @State homeMode: string = 'AUTO'          // 全屋模式：AUTO 自动 / MANUAL 手动（硬件 ModeStatus 同步）
  @State modeSwitching: boolean = false     // 模式切换请求中（防连点）
  @State isLogin: boolean = false

  /**
   * 刷新信号（来自 Index）：登录成功 router.back() 回来时 +1。
   * Tab 子页面没有 onPageShow，靠它才知道"该重新拉数据了"。
   */
  @Prop @Watch('onSignalChange') refreshTick: number = 0

  /**
   * 当前 Tab 是否可见（来自 Index 的 currentIndex === 0）。
   * Tabs 的子页面切走后不会销毁，setInterval 会一直跑——
   * 让轮询跟着可见性起停，省电省流量。
   */
  @Prop @Watch('onSignalChange') visible: boolean = false

  private timerId: number = -1        // 轮询定时器 id，便于清理
  private loading: boolean = false    // 上一轮请求是否还在飞（防止请求堆积）

  /**
   * 轮询间隔：2026-11-20 从 5s 降到 1s，配合设备端 1s 上报周期，
   * 数据变化 → App 可见的最坏延迟从 8s 压到 ~2s（体感实时）。
   * overview 是本地库轻查询，1s 轮询没有压力；防重入由 loading 标志保证。
   */
  private static readonly POLL_MS: number = 1000

  /** refreshTick / visible 任一变化都重新同步一次轮询状态 */
  onSignalChange() {
    this.sync()
  }

  aboutToAppear() {
    this.sync()
  }

  aboutToDisappear() {
    this.stopPolling()      // 不清会内存泄漏并在后台持续发请求
  }

  /**
   * 按「登录态 + 可见性」决定要不要拉数据、要不要轮询。
   * 未登录时什么都不请求 —— 否则每个轮询周期都会拿到 401。
   */
  async sync() {
    this.isLogin = TokenStore.isLogin()
    if (!this.isLogin) {
      this.stopPolling()
      // 未登录就把数据清空，避免残留上一个账号的设备
      this.rooms = []
      this.devices = []
      return
    }
    if (!this.visible) {
      this.stopPolling()
      return
    }
    await this.loadOverview(true)      // 切回本 Tab 立即刷新一次
    this.startPolling()
  }

  startPolling() {
    if (this.timerId !== -1) {
      return     // 已经在轮询，别重复起（否则请求会成倍增长）
    }
    this.timerId = setInterval(() => {
      this.loadOverview(true)
    }, HomePage.POLL_MS)
  }

  stopPolling() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /**
   * 加载首页总览。
   * @param silent 静默刷新（轮询用）：不显示 loading，避免界面闪动
   */
  async loadOverview(silent: boolean = false) {
    // 防重入：上一轮还没返回就跳过这次，避免网络慢时请求越堆越多
    if (this.loading) {
      return
    }
    if (!TokenStore.isLogin()) {
      this.stopPolling()
      return
    }
    this.loading = true
    try {
      const res = await DeviceApi.overview()
      if (res.code === 200 && res.data) {
        this.homeName = res.data.homeName
        this.rooms = res.data.rooms
        this.devices = res.data.devices
        this.homeMode = res.data.mode === 'MANUAL' ? 'MANUAL' : 'AUTO'
        // 房间数量变化时修正选中索引，防止越界
        if (this.currentRoomIndex >= this.rooms.length) {
          this.currentRoomIndex = 0
        }
      } else if (res.code === 401) {
        // token 失效：停止轮询（HttpClient 已负责清理和提示）
        this.stopPolling()
        this.isLogin = false
      }
    } finally {
      this.loading = false
    }
  }

  /** 按当前选中房间过滤设备 */
  currentDevices(): Device[] {
    if (this.rooms.length === 0) {
      return this.devices
    }
    const roomId: number = this.rooms[this.currentRoomIndex].id
    return this.devices.filter((d: Device) => d.roomId === roomId)
  }

  /**
   * 切换全屋自动/手动模式。
   * 先发请求，成功后更新本地状态；失败时 Toggle 自动回弹（isOn 由 homeMode 驱动）。
   * 自动模式联动（硬件固件实现）：天黑开客厅灯、升温开风扇、来人开客厅自动门、
   * 烟雾报警（任何模式都生效）蜂鸣器响 + 风扇排烟。
   */
  async toggleMode(auto: boolean) {
    if (this.modeSwitching) {
      return
    }
    const next: string = auto ? 'AUTO' : 'MANUAL'
    if (next === this.homeMode) {
      return
    }
    this.modeSwitching = true
    try {
      const res = await DeviceApi.setMode(next)
      if (res.code === 200 && res.data) {
        this.homeMode = res.data
        promptAction.showToast({ message: auto ? '已切换为自动模式' : '已切换为手动模式' })
      }
    } finally {
      this.modeSwitching = false
    }
  }

  /** 模式卡说明文案：随模式变化 */
  private modeDesc(): string {
    if (this.homeMode === 'AUTO') {
      return '天黑开灯 · 升温开风扇 · 来人开门 · 烟雾报警'
    }
    return '设备由你控制 · 烟雾报警始终生效'
  }

  build() {
    Column() {
      // ---------- 顶部标题栏（米家风格：大号加粗标题 + 圆形"+"按钮） ----------
      Row({ space: 12 }) {
        Text(this.homeName).fontSize(26).fontWeight(FontWeight.Bold)
          .fontColor(Const.TEXT_MAIN)
        Text('▾').fontSize(14).fontColor(Const.TEXT_SUB).margin({ top: 8 })
        Blank()
        Text('+')
          .fontSize(22).fontColor(Const.TEXT_MAIN)
          .width(38).height(38).textAlign(TextAlign.Center)
          .backgroundColor(Const.CARD_BG).borderRadius(19)
          .onClick(() => {
            // 未登录先引导登录（登录态差异处理）
            if (!TokenStore.isLogin()) {
              router.pushUrl({ url: 'pages/login/LoginPage' })
              return
            }
            router.pushUrl({ url: 'pages/device/AddDevicePage' })
          })
      }
      .width('100%').padding({ left: 20, right: 16, top: 16, bottom: 12 })

      Scroll() {
        Column({ space: Const.CARD_GAP }) {
          // ---------- 今日天气面板（和风天气，每 60 分钟自动刷新）----------
          // visible 透传：切走 Tab 时面板内部停掉小时定时器（Tabs 子页不销毁的坑）
          WeatherPanel({ visible: this.visible })

          // ---------- 全屋模式卡（自动/手动切换，2026-11-20 新增）----------
          Row({ space: 12 }) {
            Text(this.homeMode === 'AUTO' ? '⚙' : '✋')
              .fontSize(22)
              .width(46).height(46)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.homeMode === 'AUTO' ? Const.BRAND_LIGHT : '#F2F3F5')
              .borderRadius(14)
            Column({ space: 3 }) {
              Text(this.homeMode === 'AUTO' ? '自动模式' : '手动模式')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
              Text(this.modeDesc())
                .fontSize(11).fontColor(Const.TEXT_SUB)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.homeMode === 'AUTO' })
              .selectedColor(Const.BRAND)
              .onChange((isOn: boolean) => {
                this.toggleMode(isOn)
              })
          }
          .width('100%').padding({ left: 14, right: 14, top: 14, bottom: 14 })
          .backgroundColor(Const.CARD_BG)
          .borderRadius(Const.CARD_RADIUS)
          .alignItems(VerticalAlign.Center)

          // ---------- 房间切换（米家风格胶囊：选中深蓝、未选中白卡） ----------
          Row({ space: 8 }) {
            ForEach(this.rooms, (room: Room, index: number) => {
              Text(room.name)
                .fontSize(13)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(18)
                .backgroundColor(index === this.currentRoomIndex ? Const.BRAND_BLUE : Const.CARD_BG)
                .fontColor(index === this.currentRoomIndex ? Color.White : Const.TEXT_MAIN)
                .onClick(() => {
                  this.currentRoomIndex = index
                  this.loadOverview(true)     // 切房间立即刷新
                })
            }, (room: Room) => `${room.id}_${room.name}`)
          }.width('100%')

          // ---------- 设备列表（米家风格：整行卡片，图标块 + 名称/状态 + 开关圆点） ----------
          if (this.currentDevices().length === 0) {
            EmptyView({
              text: '这个房间还没有设备',
              buttonText: '添加设备',
              onAction: () => {
                router.pushUrl({ url: 'pages/device/AddDevicePage' })
              }
            })
          } else {
            Column({ space: Const.CARD_GAP }) {
              ForEach(this.currentDevices(), (device: Device) => {
                DeviceCard({
                  device: device,
                  onChanged: () => {
                    this.loadOverview(true)   // 控制成功后刷新
                  }
                })
              }, (device: Device) => {
                // 【关键】key 不能只用 id！把会变的字段拼进 key，
                // 状态一变 key 就变，组件才会用新数据重建（手册踩坑 14）
                return `${device.id}_${device.name}_${device.online}_${JSON.stringify(device.status)}`
              })
            }.width('100%')
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)               // 占满剩余空间，实现内容滚动
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    // 米家风格的"天空蓝渐变"页面底：顶部淡蓝自然过渡到浅灰页面底色
    .linearGradient({
      angle: 180,
      colors: [[Const.PAGE_SKY, 0], [Const.PAGE_BG, 0.22]]
    })
  }
}
