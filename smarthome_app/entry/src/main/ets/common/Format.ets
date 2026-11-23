// common/Format.ets —— 格式化工具（前端手册 4.5 节）
import { DeviceStatus, RoomEnv } from '../model/Device'
import { colorTempName } from './DeviceOptions'
import { Const } from './Const'

export class Format {
  /** 金额：19 → ¥19.00 */
  static money(amount: number): string {
    return `¥${amount.toFixed(2)}`
  }

  /**
   * 设备状态一句话描述：设备卡片副标题用。
   * 【2026-11-19 对齐硬件】可控设备开关都是 power；自动门 on = 开门。
   * 只读传感器显示硬件上报的实时值。
   * 【2026-11-20】环境检测卡片简化：只显示在线状态（数值看环境监测面板）。
   */
  static deviceStatusText(type: string, status: DeviceStatus, online: number = 1): string {
    const on: boolean = status.power === 'on'
    if (type === Const.DEV_LIGHT) {
      return on
        ? `已开启 · 亮度 ${status.brightness ?? 0}% · ${colorTempName(status.colorTemp ?? 4000)}`
        : '已关闭'
    }
    if (type === Const.DEV_FAN) {
      return on ? '运行中' : '已关闭'
    }
    if (type === Const.DEV_GATE) {
      return on ? '已开门' : '已关门'
    }
    if (type === Const.DEV_BEEP) {
      return on ? '鸣响中' : '已静音'
    }
    if (type === Const.DEV_SMOKE_SENSOR) {
      if (status.alarm === 1) {
        return '⚠ 烟雾报警'
      }
      return `状态正常 · 电量 ${status.battery ?? 100}%`
    }
    if (type === Const.DEV_ENV_SENSOR) {
      if (online !== 1) {
        return '离线'
      }
      const t: number | null = status.temperature ?? null
      const h: number | null = status.humidity ?? null
      const l: number | null = status.lux ?? null
      return `${t === null ? '--' : t.toFixed(1)}℃ · ${h === null ? '--' : h}% · ${l === null ? '--' : Math.round(l)}lx`
    }
    if (type === Const.DEV_PIR_SENSOR) {
      return status.present === 'on' ? '有人活动' : '无人'
    }
    return on ? '已开启' : '已关闭'
  }

  /**
   * 环境告警一句话描述：主页环境面板的红色告警条用。
   * 【2026-11-19 对齐硬件】环境面板不再产生告警（告警走烟雾传感器卡片），恒返回空串。
   */
  static envAlarmText(env: RoomEnv): string {
    return ''
  }
}
