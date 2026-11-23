// view/DeviceCard.ets —— 设备卡片组件（前端手册 6.3）
// 【2026-09-29 视觉重做】米家风格：白色大圆角卡片，左上"图标块"，右上电源圆点，
// 名称加粗、状态浅灰一行。
// 【2026-11-19 对齐硬件】可控设备的开关语义统一为 power（自动门 on = 开门），
// 卡片开关圆点对所有可控类型都直接发 { power }；只读传感器不渲染开关。
import { router } from '@kit.ArkUI'
import { Device, DeviceAction } from '../model/Device'
import { DeviceApi } from '../api/DeviceApi'
import { Const, deviceTypeName, deviceTypeIcon } from '../common/Const'
import { Format } from '../common/Format'

@Component
export struct DeviceCard {
  @Prop device: Device                 // @Prop：父组件传值
  onChanged: () => void = () => {}     // 控制成功后通知父组件刷新

  /** 是否处于"开启"状态：可控设备统一看 power */
  private isOn(): boolean {
    return this.device.status.power === 'on'
  }

  /**
   * 是否只读传感器（烟雾 / 环境检测 / 人体感应）：数值由硬件上报同步，
   * App 上没有真实的开关可发，不渲染电源圆点。
   */
  private isReadOnly(): boolean {
    const t: string = this.device.type
    return t === Const.DEV_SMOKE_SENSOR || t === Const.DEV_ENV_SENSOR || t === Const.DEV_PIR_SENSOR
  }

  /** 点击开关圆点：统一发 power on/off */
  async togglePower() {
    const next: boolean = !this.isOn()
    const action: DeviceAction = { power: next ? 'on' : 'off' }
    const res = await DeviceApi.control(this.device.id, action)
    if (res.code === 200 && res.data) {
      this.device = res.data
      this.onChanged()
    }
  }

  /** 图标块底色：开启时淡绿、关闭时浅灰（一眼分辨设备状态） */
  private iconBg(): string {
    return this.isOn() ? Const.BRAND_LIGHT : '#F2F3F5'
  }

  build() {
    Row({ space: 12 }) {
      // 左：图标块（米家风格：圆角方块 + 类型图标）
      Text(deviceTypeIcon(this.device.type))
        .fontSize(22)
        .width(46).height(46)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.iconBg())
        .borderRadius(14)

      // 中：名称 + 状态
      Column({ space: 3 }) {
        Text(this.device.name)
          .fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor(Const.TEXT_MAIN)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(Format.deviceStatusText(this.device.type, this.device.status, this.device.online))
          .fontSize(12).fontColor(Const.TEXT_SUB)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右：开关圆点（只读传感器没有真实开关，不渲染）
      if (!this.isReadOnly()) {
        Circle({ width: 26, height: 26 })
          .fill(this.isOn() ? Const.BRAND : '#E5E7EA')
          .onClick(() => this.togglePower())
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(Const.CARD_BG)
    .borderRadius(Const.CARD_RADIUS)
    .alignItems(VerticalAlign.Center)
    // 点卡片进详情页
    .onClick(() => {
      router.pushUrl({ url: 'pages/device/DeviceDetailPage', params: { deviceId: this.device.id } })
    })
  }
}
