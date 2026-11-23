// pages/device/DeviceDetailPage.ets —— 设备详情页（@Entry 子页面，手册 6.4）
//
// 【2026-11-19 对齐硬件】设备收敛为 7 种（与实训箱 Smart_Home_Demo 一致）：
//   灯   light  ：开关 / 亮度 / 色温（暖光·自然光·冷白光）
//   风扇 fan    ：开关（硬件 Motor_control）
//   自动门 gate ：开门 / 关门（硬件 Servo_control，power on = 开门）
//   蜂鸣器 beep ：鸣响 / 静音（硬件 Beep_control）
//   烟雾传感器 smoke_sensor：只读（浓度/报警位/电量由硬件 SmokeStatus 同步）
//   环境检测 env_sensor：只读（温湿度/光照由硬件上报同步）
//   人体感应 pir_sensor：只读（有人/无人由硬件 PIR_Status 同步）
//   **可控类型**：每日定时开关（后端 DeviceTimedTask 每分钟扫描执行并转发云端）
//
// 【2026-09-27 修复"带数值的文本不联动"】详情体整体包进快照 key 的 ForEach（见
//   snapKeys() / detailBody()）：任何一个数值变了 → key 变 → 整块销毁重建，
//   所有文本 / 色温圆点必然显示最新值（与胶囊选项行的 key 机制同源）。
// 【2026-09-27 操作记录上限】只展示最近 20 条，防止列表无限增长。
//
// 5 秒轮询，拖滑杆时用 dragging 标记暂停覆盖（避免滑杆被服务端值拽走）。
import { router, promptAction } from '@kit.ArkUI'
import { DeviceApi } from '../../api/DeviceApi'
import { Device, DeviceAction, DeviceStatus, DeviceLogItem } from '../../model/Device'
import { Const, deviceTypeName } from '../../common/Const'
import { LIGHT_COLOR_TEMPS, TIMER_TIMES,
  DeviceOption, colorTempName, colorTempHex, timerSummary } from '../../common/DeviceOptions'
import { EmptyView } from '../../view/EmptyView'

interface DetailParams {
  deviceId: number
}

/** 操作记录展示上限（超出只保留最近的，见 loadLogs） */
const LOG_LIMIT: number = 20

@Entry
@Component
struct DeviceDetailPage {
  @State device: Device | null = null
  @State logs: DeviceLogItem[] = []
  private deviceId: number = 0
  private timerId: number = -1        // 详情页轮询定时器
  private loading: boolean = false    // 防重入：上一轮没回来就跳过
  private dragging: boolean = false   // 是否正在拖滑杆：拖动时不让轮询覆盖界面
  private latestSeq: number = 0       // 请求序号：只认最新请求的响应（防旧值后到把界面拽回去）
  private lastMoveTick: number = 0    // 滑杆 Move 事件节流时间戳（500ms 发一次，避免请求风暴）

  /** 请求发起前调用：拿一个递增序号 */
  private nextSeq(): number {
    this.latestSeq += 1
    return this.latestSeq
  }

  /** 响应回来时序号已落后 = 期间又发过新请求，本次响应作废 */
  private isStale(seq: number): boolean {
    return seq < this.latestSeq
  }

  aboutToAppear() {
    // 从路由参数拿到设备 id
    const params = router.getParams() as DetailParams
    this.deviceId = params.deviceId
    this.loadDetail()
    this.loadLogs()
    // 每 5 秒静默刷新一次：设备状态可能被场景/定时任务改动
    this.timerId = setInterval(() => {
      this.loadDetail(true)
    }, 5000)
  }

  aboutToDisappear() {
    // @Entry 页面 router.back() 时会触发，必须清掉定时器
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /**
   * 拉取设备详情。
   * @param silent 轮询用：拖滑杆时跳过本次，避免滑杆被服务端值"拽走"
   */
  async loadDetail(silent: boolean = false) {
    if (this.loading) {
      return
    }
    if (silent && this.dragging) {
      return
    }
    this.loading = true
    const seq: number = this.nextSeq()   // 拿序号：期间若发了控制请求，本次轮询响应作废
    try {
      const res = await DeviceApi.deviceDetail(this.deviceId)
      if (this.isStale(seq)) {
        return                           // 控制请求已发出：轮询的旧值不能覆盖界面
      }
      if (res.code === 200 && res.data) {
        this.device = res.data          // @State 整体重新赋值才会触发界面刷新
      } else if (res.code === 401) {
        this.stopPolling()              // 登录态失效就别再刷了
      }
    } finally {
      this.loading = false
    }
  }

  /** 拉取设备操作记录（控制成功后也刷新一次）。【上限】只保留最近 20 条 */
  async loadLogs() {
    const res = await DeviceApi.deviceLogs(this.deviceId)
    if (res.code === 200 && res.data) {
      this.logs = res.data.slice(0, LOG_LIMIT)
    }
  }

  stopPolling() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /**
   * 统一的控制入口：不同控件传不同的 action（必须是 DeviceAction 类型，见手册 5.0 ①）。
   * @param tip 控制成功后的提示文案；传了才弹（滑杆拖动过程不弹，End/Click 才弹）
   */
  async doControl(action: DeviceAction, tip?: string) {
    const seq: number = this.nextSeq()   // 拿序号：响应回来时若已有更新请求，本次作废
    const res = await DeviceApi.control(this.deviceId, action)
    if (this.isStale(seq)) {
      return                             // 用户又动了新控件：旧响应不得回写界面（"调了跳回去"的根因）
    }
    if (res.code === 200 && res.data) {
      this.device = res.data
      if (tip !== undefined) {
        promptAction.showToast({ message: tip })
      }
      this.loadLogs()
    } else if (res.code !== 200) {
      // 后端做了范围校验（阈值 10~150 等），越界会报错 —— 必须让用户看到原因
      promptAction.showToast({ message: res.msg })
    }
  }

  /**
   * 滑杆统一入口（2026-09-29 修复"调了不变"）：
   *  · Begin：只标记 dragging，挡住轮询；
   *  · Move：节流 500ms 下发一次（数值实时跟手，又不会每格一请求刷爆后端）；
   *  · End/Click：必发一次最终值。
   * 配合 doControl 的序号防乱序，拖得再快界面也只会停在最后一次的值上。
   * @param key   要下发的字段名（brightness）
   * @param label End/Click 时弹的 toast 文案生成器；Move 过程不弹
   */
  private sliderChange(key: string, value: number, mode: SliderChangeMode,
                       label?: (v: number) => string) {
    if (mode === SliderChangeMode.Begin) {
      this.dragging = true
      return
    }
    const v: number = Math.round(value)
    if (mode === SliderChangeMode.Moving) {
      const now: number = Date.now()
      if (now - this.lastMoveTick >= 500) {
        this.lastMoveTick = now
        const action: DeviceAction = {}
        this.fillAction(action, key, v)
        this.doControl(action)
      }
      return
    }
    // End / Click：最终值必发
    this.dragging = false
    this.lastMoveTick = 0
    const action: DeviceAction = {}
    this.fillAction(action, key, v)
    this.doControl(action, label !== undefined ? label(v) : undefined)
  }

  /** 按字段名把数值装进 action（滑杆字段统一在这里登记，漏了就发不出去） */
  private fillAction(action: DeviceAction, key: string, v: number): void {
    if (key === 'brightness') {
      action.brightness = v
    }
  }

  // ==================== 状态读取（口径统一在这里，别在 build 里散着算） ====================

  /** 是否只读传感器（烟雾 / 环境检测 / 人体感应）：数值由硬件上报，App 不提供控制 */
  private isReadOnly(): boolean {
    const t: string = this.device!.type
    return t === Const.DEV_SMOKE_SENSOR || t === Const.DEV_ENV_SENSOR || t === Const.DEV_PIR_SENSOR
  }

  /** 是否开启（可控设备统一看 power；自动门 on = 开门，蜂鸣器 on = 鸣响） */
  private isOn(): boolean {
    return this.device!.status.power === 'on'
  }

  /** 开关按钮的文案（自动门的语义是开门/关门，其余是打开/关闭） */
  private powerWord(next: boolean): string {
    const t: string = this.device!.type
    if (t === Const.DEV_GATE) {
      return next ? '开门' : '关门'
    }
    if (t === Const.DEV_BEEP) {
      return next ? '鸣响' : '静音'
    }
    return next ? '打开' : '关闭'
  }

  /**
   * 【2026-09-27 动态文本根治】快照 key：设备数据的完整 JSON 串。
   * 详情体包在"长度恒为 1"的 ForEach 里，key 就是它 —— 任一数值变了
   * key 必变 → 整块子树销毁重建 → 所有文本 / 圆点都是最新值。
   * 注：key 用 JSON 串做等值比较，数据没变的轮询不会触发重建。
   */
  private snapKeys(): string[] {
    if (this.device === null) {
      return []
    }
    return [JSON.stringify(this.device)]
  }

  // ==================== 大号状态区文案 ====================

  /** 大号数值（不同设备的主指标） */
  private mainValue(): string {
    const st: DeviceStatus = this.device!.status
    const t: string = this.device!.type
    if (t === Const.DEV_LIGHT) {
      return this.isOn() ? `亮度 ${st.brightness ?? 0}%` : '已关闭'
    }
    if (t === Const.DEV_FAN) {
      return this.isOn() ? '运行中' : '已关闭'
    }
    if (t === Const.DEV_GATE) {
      return this.isOn() ? '已开门' : '已关门'
    }
    if (t === Const.DEV_BEEP) {
      return this.isOn() ? '鸣响中' : '已静音'
    }
    if (t === Const.DEV_SMOKE_SENSOR) {
      return st.alarm === 1 ? '⚠ 烟雾报警' : '状态正常'
    }
    if (t === Const.DEV_ENV_SENSOR) {
      const temp: number = st.temperature ?? 0
      return `${temp.toFixed(1)} ℃`
    }
    if (t === Const.DEV_PIR_SENSOR) {
      return st.present === 'on' ? '有人活动' : '无人'
    }
    return this.isOn() ? '运行中' : '已关闭'
  }

  /** 大号状态下的小字：把该设备当前的其他数值一次说清 */
  private subValue(): string {
    const st: DeviceStatus = this.device!.status
    const t: string = this.device!.type
    if (t === Const.DEV_LIGHT) {
      return `${colorTempName(st.colorTemp ?? 4000)}`
    }
    if (t === Const.DEV_SMOKE_SENSOR) {
      return `电量 ${st.battery ?? 100}% · 浓度 ${st.smoke ?? 0}ppm`
    }
    if (t === Const.DEV_ENV_SENSOR) {
      const h: number = st.humidity ?? 0
      const l: number = st.lux ?? 0
      return `湿度 ${h}% · 光照 ${Math.round(l)}lx`
    }
    return ''
  }

  // ==================== 通用胶囊选项（抽出来避免多个面板各写一遍） ====================
  //
  // 【为什么用 kind 字符串分派而不是 @Builder 传值】@Builder 的参数是**值快照**，
  // 状态变化时不会刷新（手册踩坑）。这里只在参数里传"选项数组 + 类别名"，
  // 选中判断与下发都通过 this.xxx() 现算 —— 每次渲染都取最新状态，不会僵住。

  /** 取当前选中值（字符串型选项） */
  private currentStr(kind: string): string {
    const st: DeviceStatus = this.device!.status
    if (kind === 'colorTemp') {
      return `${st.colorTemp ?? 4000}`
    }
    if (kind === 'timerOn') {
      return st.timerOn ?? ''
    }
    if (kind === 'timerOff') {
      return st.timerOff ?? ''
    }
    return ''
  }

  /** 定时"开"在该设备上的实际含义（自动门 = 开门） */
  private timerOnWord(): string {
    const t: string = this.device!.type
    if (t === Const.DEV_GATE) {
      return '开门'
    }
    if (t === Const.DEV_BEEP) {
      return '鸣响'
    }
    return '开机'
  }

  /** 定时"关"在该设备上的实际含义 */
  private timerOffWord(): string {
    const t: string = this.device!.type
    if (t === Const.DEV_GATE) {
      return '关门'
    }
    if (t === Const.DEV_BEEP) {
      return '静音'
    }
    return '关机'
  }

  /** 点字符串型选项 → 组装 action 下发 */
  private pickStr(kind: string, value: string, label: string) {
    const action: DeviceAction = {}
    let tip: string = label
    if (kind === 'colorTemp') {
      action.colorTemp = parseInt(value)
      tip = `色温已调为${label}`
    } else if (kind === 'timerOn') {
      action.timerOn = value
      tip = value.length === 0 ? '已取消定时开启' : `已设定每天 ${value} 自动${this.timerOnWord()}`
    } else if (kind === 'timerOff') {
      action.timerOff = value
      tip = value.length === 0 ? '已取消定时关闭' : `已设定每天 ${value} 自动${this.timerOffWord()}`
    }
    this.doControl(action, tip)
  }

  /** 通用「胶囊选项行」（字符串型：色温 / 定时时刻） */
  @Builder
  chipRow(options: DeviceOption[], kind: string) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(options, (opt: DeviceOption) => {
        Text(opt.label)
          .fontSize(13)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .borderRadius(Const.PILL_RADIUS)
          .backgroundColor(this.currentStr(kind) === opt.value ? Const.BRAND : Const.CARD_BG)
          .fontColor(this.currentStr(kind) === opt.value ? Color.White : Const.TEXT_BODY)
          .border({ width: 0.5, color: this.currentStr(kind) === opt.value ? Const.BRAND : Const.DIVIDER })
          .onClick(() => {
            this.pickStr(kind, opt.value, opt.label)
          })
      }, (opt: DeviceOption) => `${kind}_${opt.value}_${this.currentStr(kind) === opt.value}`)
    }
    .width('100%')
  }

  /** 小标题 */
  @Builder
  fieldLabel(text: string) {
    Text(text).fontSize(13).fontColor(Const.TEXT_SUB).width('100%').margin({ bottom: 8 })
  }

  /** 通用「每日定时」区（可控设备共用） */
  @Builder
  timerSection() {
    Column({ space: 4 }) {
      this.fieldLabel(`每日定时开启（到点自动${this.timerOnWord()}）`)
      this.chipRow(TIMER_TIMES, 'timerOn')
      this.fieldLabel(`每日定时关闭（到点自动${this.timerOffWord()}）`)
      this.chipRow(TIMER_TIMES, 'timerOff')
      Text(`当前：${timerSummary(this.device!.status.timerOn ?? '', this.device!.status.timerOff ?? '')}`)
        .fontSize(12).fontColor(Const.TEXT_SUB).width('100%').margin({ top: 4 })
    }
    .width('100%').padding(16)
    .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // 顶部返回栏
      Row() {
        Text('‹ 返回').fontSize(16).fontColor(Const.TEXT_MAIN)
          .onClick(() => router.back())
        Blank()
        Text('设备详情').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.device === null) {
        Text('加载中...').fontSize(14).fontColor(Const.TEXT_SUB).margin({ top: 100 })
      } else {
        Scroll() {
          Column() {
            // 【2026-09-27 动态文本根治】详情体包在"长度恒为 1"的 ForEach 里，
            // key = 设备数据完整 JSON 快照（snapKeys()）：任一数值变了 → key 变 →
            // 整块销毁重建 → 所有带数值的文本 / 色温圆点必然显示最新值。
            ForEach(this.snapKeys(), (_snap: string) => {
              this.detailBody()
            }, (snap: string) => snap)
          }.width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }

  /**
   * 详情体：大号状态区 + 开关 + 各类型控制面板 + 通用定时 + 操作记录。
   * 由 build() 里的 ForEach(快照 key) 调用，进入时 device 一定非空（else 分支保证）。
   */
  @Builder
  detailBody() {
    Column({ space: 16 }) {
      // ---------- 大号状态展示 ----------
      Column({ space: 8 }) {
        Text(deviceTypeName(this.device!.type)).fontSize(13).fontColor(Const.TEXT_SUB)
        Text(this.device!.name).fontSize(20).fontWeight(FontWeight.Medium)
        Text(this.mainValue()).fontSize(40).fontWeight(FontWeight.Medium)
        if (this.subValue().length > 0) {
          Text(this.subValue()).fontSize(13).fontColor(Const.TEXT_SUB)
        }
      }

      // ---------- 开关按钮（可控设备统一发 power；只读传感器不显示） ----------
      if (!this.isReadOnly()) {
        Button(this.powerWord(!this.isOn()))
          .width('60%').height(44)
          .backgroundColor(this.isOn() ? Const.CARD_BG : Const.BRAND)
          .fontColor(this.isOn() ? Const.TEXT_MAIN : Color.White)
          .borderRadius(22)
          .onClick(() => {
            const nextPower: string = this.isOn() ? 'off' : 'on'
            const action: DeviceAction = { power: nextPower }
            this.doControl(action,
              nextPower === 'on' ? `已${this.powerWord(true)}「${this.device!.name}」`
                : `已${this.powerWord(false)}「${this.device!.name}」`)
          })
      }

      // ---------- 灯面板（亮度 / 色温） ----------
      if (this.device!.type === Const.DEV_LIGHT) {
        Column({ space: 6 }) {
          this.fieldLabel(`亮度 ${this.device!.status.brightness ?? 0}%`)
          Slider({ value: this.device!.status.brightness ?? 80, min: 1, max: 100, step: 1 })
            .width('100%').selectedColor(Const.BRAND)
            .onChange((value: number, mode: SliderChangeMode) => {
              this.sliderChange('brightness', value, mode,
                (v: number) => `亮度已调到 ${v}%`)
            })

          Row({ space: 8 }) {
            Text('色温').fontSize(13).fontColor(Const.TEXT_SUB)
            Text(colorTempName(this.device!.status.colorTemp ?? 4000))
              .fontSize(13).fontColor(Const.TEXT_MAIN)
            Blank()
            Circle({ width: 14, height: 14 })
              .fill(colorTempHex(this.device!.status.colorTemp ?? 4000))
              .stroke(Const.DIVIDER).strokeWidth(0.5)
          }.width('100%').margin({ top: 6 })
          // 色温走 chipRow（LIGHT_COLOR_TEMPS 的 value 声明为字符串），
          // pickStr 里 parseInt 后再下发给后端，后端白名单校验的是数字 2700/4000/6500
          this.chipRow(LIGHT_COLOR_TEMPS, 'colorTemp')
        }
        .width('100%').padding(16)
        .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
        .alignItems(HorizontalAlign.Start)
      }

      // ---------- 烟雾传感器面板（只读：状态/浓度/电量由硬件 SmokeStatus 同步） ----------
      if (this.device!.type === Const.DEV_SMOKE_SENSOR) {
        Column({ space: 12 }) {
          Row() {
            Text('报警状态').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(this.device!.status.alarm === 1 ? '⚠ 烟雾报警' : '正常')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.device!.status.alarm === 1 ? Const.DANGER : Const.TEXT_MAIN)
          }.width('100%')
          Row() {
            Text('烟雾浓度').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(`${this.device!.status.smoke ?? 0} ppm`)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
          }.width('100%')
          Row() {
            Text('设备电量').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(`${this.device!.status.battery ?? 100}%`)
              .fontSize(14).fontColor(Const.TEXT_MAIN)
          }.width('100%')
          Text('浓度与报警位由硬件每 3 秒上报一次，经华为云实时推送到这里；报警阈值在固件内设定。')
            .fontSize(12).fontColor(Const.TEXT_SUB).width('100%')
        }
        .width('100%').padding(16)
        .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
        .alignItems(HorizontalAlign.Start)
      }

      // ---------- 环境检测面板（只读：温湿度 / 光照由硬件上报同步） ----------
      if (this.device!.type === Const.DEV_ENV_SENSOR) {
        Column({ space: 12 }) {
          Row() {
            Text('温度').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(`${(this.device!.status.temperature ?? 0).toFixed(1)} ℃`)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
          }.width('100%')
          Row() {
            Text('湿度').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(`${this.device!.status.humidity ?? 0} %`)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
          }.width('100%')
          Row() {
            Text('光照强度').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(`${Math.round(this.device!.status.lux ?? 0)} lx`)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
          }.width('100%')
          Text('数值由硬件传感器（SHT30 温湿度 / BH1750 光照）每 3 秒上报，经华为云实时推送到这里。')
            .fontSize(12).fontColor(Const.TEXT_SUB).width('100%')
        }
        .width('100%').padding(16)
        .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
        .alignItems(HorizontalAlign.Start)
      }

      // ---------- 人体感应面板（只读：有人/无人由硬件 PIR_Status 同步） ----------
      if (this.device!.type === Const.DEV_PIR_SENSOR) {
        Column({ space: 12 }) {
          Row() {
            Text('当前状态').fontSize(14).fontColor(Const.TEXT_MAIN)
            Blank()
            Text(this.device!.status.present === 'on' ? '有人活动' : '无人')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.device!.status.present === 'on' ? Const.BRAND : Const.TEXT_MAIN)
          }.width('100%')
          Text('检测由硬件人体红外传感器完成，状态每 3 秒上报一次，经华为云实时推送到这里。')
            .fontSize(12).fontColor(Const.TEXT_SUB).width('100%')
        }
        .width('100%').padding(16)
        .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
        .alignItems(HorizontalAlign.Start)
      }

      // ---------- 通用定时区（只读传感器没有开关语义，不显示） ----------
      if (!this.isReadOnly()) {
        this.timerSection()
      }

      // ---------- 操作记录（device_log，最多展示最近 20 条 2026-09-27） ----------
      Column({ space: 10 }) {
        Text('操作记录').fontSize(14).fontWeight(FontWeight.Medium)
        if (this.logs.length === 0) {
          Text('暂无操作记录').fontSize(12).fontColor(Const.TEXT_SUB)
        } else {
          ForEach(this.logs, (log: DeviceLogItem, index: number) => {
            Row() {
              Text(log.action).fontSize(12).layoutWeight(1).maxLines(2)
              Text(log.createTime).fontSize(10).fontColor(Const.TEXT_SUB)
            }.width('100%')
          }, (log: DeviceLogItem, index: number) => `${log.id}_${index}`)
          if (this.logs.length >= LOG_LIMIT) {
            Text('仅显示最近 20 条，更早的记录已折叠')
              .fontSize(11).fontColor(Const.TEXT_SUB).margin({ top: 4 })
          }
        }
      }
      .alignItems(HorizontalAlign.Start).width('100%').padding(16)
      .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
    }
    .padding(16)
  }
}
