// common/DeviceOptions.ets —— 设备控制的选项字典（灯色温 / 定时时刻）
//
// 【为什么单独一个文件，不塞进 Const.ets】Const.ets 是"色板 + 间距 + 类型"的纯常量表；
// 选项是"取值 + 中文文案"的组合数据，混进去会把常量表撑乱。放这里还能被多处复用
// （设备详情页、设备卡片、场景编辑）。
//
// 【ArkTS 约束】ArkTS 严格模式下，对象字面量必须有明确的类型来源。
// 所以每个选项数组都声明成 interface 数组，不能写成匿名结构。
//
// 【2026-11-19 对齐硬件】烟雾报警阈值在固件里烧死，SMOKE_LIMITS 选项已删除。

/** 字符串型选项：value 下发给后端，label 给用户看 */
export interface DeviceOption {
  value: string
  label: string
}

/** 数值型选项 */
export interface NumberOption {
  value: number
  label: string
}

// ---------- 灯 ----------

/** 色温：2700 暖光 / 4000 自然 / 6500 冷白（后端白名单 COLOR_TEMPS 与此一致）
 *
 * 【为什么是字符串 value 而不是 NumberOption】色温在 UI 上是**三选一**的
 * 胶囊行，走字符串路径可以直接复用详情页的 chipRow（含选中高亮）；点选后 pickStr 里再
 * parseInt 成数字下发给后端。注意：这只是"前端内部表示"，下发给后端的 JSON 仍是数字 2700/4000/6500。 */
export const LIGHT_COLOR_TEMPS: DeviceOption[] = [
  { value: '2700', label: '暖光' },
  { value: '4000', label: '自然光' },
  { value: '6500', label: '冷白光' }
]

// ---------- 通用定时 ----------

/** 每日定时开关的时刻选项（value 空串 = 不定时） */
export const TIMER_TIMES: DeviceOption[] = [
  { value: '', label: '不定时' },
  { value: '06:30', label: '06:30' },
  { value: '07:00', label: '07:00' },
  { value: '08:00', label: '08:00' },
  { value: '18:00', label: '18:00' },
  { value: '22:00', label: '22:00' },
  { value: '23:00', label: '23:00' }
]

// ---------- 取值 → 中文（列表、卡片、状态摘要共用，不要各写各的） ----------

/** 色温中文名（入参是数字，选项表里存的是字符串，比较前先 parseInt） */
export function colorTempName(v: number): string {
  for (let i = 0; i < LIGHT_COLOR_TEMPS.length; i++) {
    if (parseInt(LIGHT_COLOR_TEMPS[i].value) === v) {
      return LIGHT_COLOR_TEMPS[i].label
    }
  }
  return '自然光'
}

/** 色温对应的展示色（详情页色温胶囊上色用） */
export function colorTempHex(v: number): string {
  if (v === 2700) {
    return '#FFB74D'
  }
  if (v === 6500) {
    return '#B3D4FF'
  }
  return '#FFFFFF'
}

/** 定时摘要：定时开 07:00 / 定时关 22:00 */
export function timerSummary(timerOn: string, timerOff: string): string {
  const on: string = timerOn.length > 0 ? `${timerOn} 开` : ''
  const off: string = timerOff.length > 0 ? `${timerOff} 关` : ''
  if (on.length === 0 && off.length === 0) {
    return '未设置定时'
  }
  if (on.length > 0 && off.length > 0) {
    return `${on} · ${off}`
  }
  return on.length > 0 ? `${on}` : `${off}`
}
