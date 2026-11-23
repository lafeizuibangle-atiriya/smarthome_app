// pages/smart/SceneEditPage.ets —— 场景编辑页（@Entry 子页面，自研实现）
// 流程：填场景名 -> 选类型（手动场景 / 定时自动化）-> 勾选设备 -> 为每台设备选动作 -> 保存。
// 【数据隔离】设备列表来自 /api/home/overview，只会拿到当前登录人自己的设备。
// 【刷新注意】勾选/选动作必须重建 rows 数组整体赋值，就地改元素不会触发 @State（踩坑 14）。
import { router, promptAction } from '@kit.ArkUI'
import { DeviceApi } from '../../api/DeviceApi'
import { SceneApi, SceneSaveParam, SceneActionParam } from '../../api/SceneApi'
import { Device, DeviceAction } from '../../model/Device'
import { Const, deviceTypeName } from '../../common/Const'
import { EmptyView } from '../../view/EmptyView'

/** 一台设备在编辑页里的行状态 */
interface SceneDeviceRow {
  id: number
  name: string
  type: string
  selected: boolean
  actionIdx: number      // 选中的动作下标（对 actionPresets(type) 的下标）
}

/** 一个动作预设：label 是给用户看的文案，action 是要发给后端的 JSON 对象 */
interface ActionPreset {
  label: string
  action: DeviceAction
}

@Entry
@Component
struct SceneEditPage {
  @State sceneName: string = ''
  @State triggerType: string = 'MANUAL'       // MANUAL 手动场景 | TIMER 定时自动化
  @State cronExpr: string = ''                // 定时自动化的 HH:mm
  @State rows: SceneDeviceRow[] = []
  @State saving: boolean = false

  aboutToAppear() {
    this.loadDevices()
  }

  async loadDevices() {
    const res = await DeviceApi.overview()
    if (res.code === 200 && res.data) {
      this.rows = res.data.devices.map((device: Device) => {
        const row: SceneDeviceRow = {
          id: device.id, name: device.name, type: device.type,
          selected: false, actionIdx: 0
        }
        return row
      })
    }
  }

  /**
   * 每种设备类型的动作预设（可控设备的开关都是 power；自动门 on = 开门）。
   * 只读传感器（烟雾 / 环境检测 / 人体感应）没有可执行动作，返回空数组，
   * 场景编辑页据此隐藏它们。
   */
  private actionPresets(type: string): ActionPreset[] {
    if (type === Const.DEV_LIGHT) {
      return [
        { label: '开灯', action: { power: 'on', brightness: 80 } },
        { label: '关灯', action: { power: 'off' } }
      ]
    }
    if (type === Const.DEV_GATE) {
      return [
        { label: '开门', action: { power: 'on' } },
        { label: '关门', action: { power: 'off' } }
      ]
    }
    if (type === Const.DEV_BEEP) {
      return [
        { label: '鸣响', action: { power: 'on' } },
        { label: '静音', action: { power: 'off' } }
      ]
    }
    if (type === Const.DEV_SMOKE_SENSOR || type === Const.DEV_ENV_SENSOR
      || type === Const.DEV_PIR_SENSOR) {
      return []       // 只读传感器：没有可执行动作
    }
    // fan 及其余可控类型
    return [
      { label: '打开', action: { power: 'on' } },
      { label: '关闭', action: { power: 'off' } }
    ]
  }

  /** 重建 rows（整体赋值触发刷新）：改勾选或改动作都走这里 */
  private updateRow(row: SceneDeviceRow, selected: boolean, actionIdx: number) {
    const next: SceneDeviceRow[] = this.rows.slice()
    for (let i = 0; i < next.length; i++) {
      if (next[i].id === row.id) {
        const updated: SceneDeviceRow = {
          id: row.id, name: row.name, type: row.type,
          selected: selected, actionIdx: actionIdx
        }
        next[i] = updated
      }
    }
    this.rows = next
  }

  /** 定时自动化的可选时刻（与后端 SceneTimedTask 的 HH:mm 口径一致） */
  private timePresets: string[] = ['06:30', '07:30', '12:00', '19:00', '23:00']

  async save() {
    if (this.sceneName.length === 0) {
      promptAction.showToast({ message: '请填写场景名称' })
      return
    }
    if (this.triggerType === 'TIMER' && this.cronExpr.length === 0) {
      promptAction.showToast({ message: '请选择触发时间' })
      return
    }
    const chosen: SceneDeviceRow[] = this.rows.filter((row: SceneDeviceRow) => row.selected)
    if (chosen.length === 0) {
      promptAction.showToast({ message: '请至少勾选一台设备' })
      return
    }
    this.saving = true
    const actions: SceneActionParam[] = chosen.map((row: SceneDeviceRow) => {
      const preset: ActionPreset = this.actionPresets(row.type)[row.actionIdx]
      const param: SceneActionParam = {
        deviceId: row.id,
        action: JSON.stringify(preset.action)     // 后端存 JSON 字符串
      }
      return param
    })
    const saveParam: SceneSaveParam = {
      name: this.sceneName,
      triggerType: this.triggerType,
      cronExpr: this.triggerType === 'TIMER' ? this.cronExpr : '',
      actions: actions
    }
    const res = await SceneApi.save(saveParam)
    this.saving = false
    if (res.code === 200) {
      promptAction.showToast({ message: '保存成功' })
      router.back()
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('新建场景').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      Scroll() {
        Column({ space: Const.CARD_GAP }) {
          // ---------- 场景名 ----------
          Column({ space: 8 }) {
            Text('场景名称').fontSize(14).fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '例如：观影模式' })
              .height(44).backgroundColor(Const.CARD_BG)
              .onChange((value: string) => {
                this.sceneName = value
              })
          }
          .alignItems(HorizontalAlign.Start).width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // ---------- 类型 ----------
          Column({ space: 8 }) {
            Text('类型').fontSize(14).fontWeight(FontWeight.Medium)
            Row({ space: 8 }) {
              Text('手动场景（一键执行）').fontSize(13)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 }).borderRadius(16)
                .backgroundColor(this.triggerType === 'MANUAL' ? Const.BRAND : Const.CARD_BG)
                .fontColor(this.triggerType === 'MANUAL' ? Color.White : Const.TEXT_MAIN)
                .onClick(() => {
                  this.triggerType = 'MANUAL'
                })
              Text('定时自动化').fontSize(13)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 }).borderRadius(16)
                .backgroundColor(this.triggerType === 'TIMER' ? Const.BRAND : Const.CARD_BG)
                .fontColor(this.triggerType === 'TIMER' ? Color.White : Const.TEXT_MAIN)
                .onClick(() => {
                  this.triggerType = 'TIMER'
                })
              if (this.triggerType === 'TIMER') {
                ForEach(this.timePresets, (time: string) => {
                  Text(time).fontSize(12)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(14)
                    .backgroundColor(this.cronExpr === time ? Const.BRAND : Const.PAGE_BG)
                    .fontColor(this.cronExpr === time ? Color.White : Const.TEXT_BODY)
                    .onClick(() => {
                      this.cronExpr = time
                    })
                }, (time: string) => time)
              }
            }
          }
          .alignItems(HorizontalAlign.Start).width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // ---------- 勾选设备与动作 ----------
          Text('选择设备并设置动作').fontSize(14).fontWeight(FontWeight.Medium).width('100%')
          if (this.rows.length === 0) {
            EmptyView({ text: '还没有设备，先去首页添加' })
          } else {
            ForEach(this.rows, (row: SceneDeviceRow) => {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Checkbox({ name: row.id.toString(), group: 'scene' })
                    .select(row.selected)
                    .selectedColor(Const.BRAND)
                    .onChange((checked: boolean) => {
                      this.updateRow(row, checked, row.actionIdx)
                    })
                  Text(row.name).fontSize(14).layoutWeight(1).maxLines(1)
                  Text(deviceTypeName(row.type)).fontSize(12).fontColor(Const.TEXT_SUB)
                }.width('100%')

                // 勾选后显示动作选项（两种动作二选一）
                if (row.selected) {
                  Row({ space: 8 }) {
                    ForEach(this.actionPresets(row.type), (preset: ActionPreset, index: number) => {
                      Text(preset.label).fontSize(12)
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .borderRadius(14)
                        .backgroundColor(row.actionIdx === index ? Const.BRAND : Const.PAGE_BG)
                        .fontColor(row.actionIdx === index ? Color.White : Const.TEXT_BODY)
                        .onClick(() => {
                          this.updateRow(row, row.selected, index)
                        })
                    }, (preset: ActionPreset, index: number) => `${row.id}_${index}_${preset.label}`)
                  }.width('100%')
                }
              }
              .width('100%').padding(14)
              .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
            }, (row: SceneDeviceRow) =>
              `${row.id}_${row.selected ? 1 : 0}_${row.actionIdx}_${row.name}`)
          }
        }.padding({ left: 16, right: 16, bottom: 80 })
      }.layoutWeight(1).scrollBar(BarState.Off)

      // ---------- 底部保存 ----------
      Row() {
        Button(this.saving ? '保存中...' : '保存场景')
          .width('80%').height(44).borderRadius(22)
          .backgroundColor(Const.BRAND).fontColor(Color.White)
          .enabled(!this.saving)
          .onClick(() => {
            this.save()
          })
      }
      .width('100%').padding(16).backgroundColor(Const.CARD_BG)
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
