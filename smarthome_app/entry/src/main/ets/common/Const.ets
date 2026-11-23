// common/Const.ets —— 全 App 统一常量：色板 / 间距 / 设备类型。
// 改这里 = 全局换肤，页面里禁止写死色值（总方案 6.1 + 前端手册 4.4）。
//
// 【2026-09-29 视觉重做 · 米家风格】参考米家 App 截图统一视觉语言：
//   · 页面底色浅灰 #F4F6F8，内容全部装进"白色大圆角卡片"（20+ 圆角）
//   · 强调色改为米家绿（开关 / 主按钮 / 选中态），信息类强调保留米家蓝
// 【2026-11-19 对齐硬件】设备类型收敛为 5 种，与实训箱（Smart_Home_Demo）一一对应。
export class Const {
  // ---- 色板（米家风格）----
  static readonly BRAND: string = '#0BC15C'          // 主色：米家绿（按钮 / 选中态 / 开关）
  static readonly BRAND_LIGHT: string = '#E7F8EF'    // 主色浅底
  static readonly BRAND_BLUE: string = '#4C7DD8'     // 信息类强调：环境主卡 / 天气（米家蓝）
  static readonly BRAND_BLUE_LIGHT: string = '#EAF1FC'
  static readonly PAGE_BG: string = '#F4F6F8'        // 页面底色（浅灰）
  static readonly PAGE_SKY: string = '#C3DCF4'       // 首页顶部天空蓝（渐变起点）
  static readonly CARD_BG: string = '#FFFFFF'        // 卡片
  static readonly TEXT_MAIN: string = '#141414'      // 主文字（更黑，米家的大标题感）
  static readonly TEXT_BODY: string = '#4B4B4B'      // 正文
  static readonly TEXT_SUB: string = '#9C9C9C'       // 次要/状态
  static readonly DIVIDER: string = '#EFEFEF'        // 分割线、描边
  static readonly SUCCESS: string = '#0BC15C'        // 在线/成功
  static readonly DANGER: string = '#FA5151'         // 离线/警告/删除
  static readonly SWITCH_OFF: string = '#E3E3E3'     // 开关关闭态

  // 环境监测三档色（正常 / 注意 / 报警）
  static readonly ENV_OK: string = '#0BC15C'
  static readonly ENV_WARN: string = '#FF9F2E'
  static readonly ENV_ALARM: string = '#FA5151'

  // ---- 间距与圆角（米家的卡片更"圆润"：小控件 10 / 卡片 20 / 胶囊 24）----
  static readonly PAGE_PADDING: number = 16
  static readonly RADIUS_SMALL: number = 10
  static readonly CARD_RADIUS: number = 20
  static readonly PILL_RADIUS: number = 24
  static readonly CARD_GAP: number = 12

  // ---- 设备类型（2026-11-19 起共 7 种，与硬件侧设备一一对应）----
  // 【新增类型四处同步】这里 / deviceTypeName() / 后端 types() 字典 / AddDevicePage 类型数组
  static readonly DEV_LIGHT: string = 'light'               // 灯：开关 / 亮度 / 色温
  static readonly DEV_FAN: string = 'fan'                   // 风扇：开关（Motor_control）
  static readonly DEV_GATE: string = 'gate'                 // 舵机自动门：开门 / 关门（Servo_control）
  static readonly DEV_BEEP: string = 'beep'                 // 蜂鸣器：鸣响 / 静音（Beep_control）
  static readonly DEV_SMOKE_SENSOR: string = 'smoke_sensor' // 烟雾传感器：状态跟随硬件上报
  static readonly DEV_ENV_SENSOR: string = 'env_sensor'     // 环境检测：温湿度 + 光照（只读，阳台）
  static readonly DEV_PIR_SENSOR: string = 'pir_sensor'     // 人体感应：有人 / 无人（只读，卧室）
}

/** 设备类型 -> 中文名：所有页面显示统一调它，不要各写各的 */
export function deviceTypeName(type: string): string {
  if (type === Const.DEV_LIGHT) return '灯'
  if (type === Const.DEV_FAN) return '风扇'
  if (type === Const.DEV_GATE) return '自动门'
  if (type === Const.DEV_BEEP) return '蜂鸣器'
  if (type === Const.DEV_SMOKE_SENSOR) return '烟雾传感器'
  if (type === Const.DEV_ENV_SENSOR) return '环境检测'
  if (type === Const.DEV_PIR_SENSOR) return '人体感应'
  return '设备'
}

/** 设备类型 -> 图标 emoji：设备卡片 / 添加设备页统一用（Demo 用 emoji 顶替图标资源） */
export function deviceTypeIcon(type: string): string {
  if (type === Const.DEV_LIGHT) return '💡'
  if (type === Const.DEV_FAN) return '🌀'
  if (type === Const.DEV_GATE) return '🚪'
  if (type === Const.DEV_BEEP) return '🔔'
  if (type === Const.DEV_SMOKE_SENSOR) return '🚨'
  if (type === Const.DEV_ENV_SENSOR) return '🌡️'
  if (type === Const.DEV_PIR_SENSOR) return '👁️'
  return '📱'
}
