// pages/smart/AutoDetailPage.ets —— 自动化详情页（@Entry 子页面，自研实现）
// 展示定时自动化的触发时间、执行动作列表、启停开关；支持改时间与删除。
// 动作列表每条都会真实下发：run 时后端逐条调 deviceService.control()（一个事务）。
import { router, promptAction } from '@kit.ArkUI'
import { SceneApi, SceneActionParam } from '../../api/SceneApi'
import { Scene, SceneActionItem } from '../../model/Scene'
import { Const } from '../../common/Const'
import { EmptyView } from '../../view/EmptyView'

interface AutoParams {
  sceneId: number
}

@Entry
@Component
struct AutoDetailPage {
  @State scene: Scene | null = null
  @State enabledOn: boolean = false     // ⚠️ 不能叫 enabled，会和内置属性方法冲突
  @State showTimePresets: boolean = false
  private sceneId: number = 0
  private timePresets: string[] = ['06:30', '07:30', '12:00', '19:00', '23:00']

  aboutToAppear() {
    const params = router.getParams() as AutoParams
    this.sceneId = params.sceneId
    this.load()
  }

  async load() {
    const res = await SceneApi.detail(this.sceneId)
    if (res.code === 200 && res.data) {
      this.scene = res.data
      this.enabledOn = res.data.enabled === 1
    }
  }

  /** 启停：启停是用户主动操作且留在本页 → 明确 toast（手册 4.3.2） */
  async toggle(on: boolean) {
    const next: number = on ? 1 : 0
    const res = await SceneApi.toggle(this.sceneId, next)
    if (res.code === 200) {
      this.enabledOn = on
      promptAction.showToast({ message: on ? '自动化已启用' : '自动化已停用' })
    }
  }

  /** 修改触发时间（PUT /api/scene，body 带原内容 + 新 cronExpr） */
  async applyTime(time: string) {
    const actions: SceneActionParam[] = this.toParams(this.scene?.actions ?? [])
    const res = await SceneApi.update({
      id: this.sceneId,
      name: this.scene?.name ?? '',
      triggerType: 'TIMER',
      cronExpr: time,
      actions: actions
    })
    if (res.code === 200) {
      promptAction.showToast({ message: `已改为每天 ${time}` })
      this.showTimePresets = false
      this.load()
    }
  }

  /** SceneActionItem[] → SceneActionParam[]（动作本身就是 JSON 字符串，直接复用） */
  private toParams(items: SceneActionItem[]): SceneActionParam[] {
    return items.map((item: SceneActionItem) => {
      const param: SceneActionParam = { deviceId: item.deviceId, action: item.action }
      return param
    })
  }

  /** 删除该自动化 */
  async remove() {
    const res = await SceneApi.remove(this.sceneId)
    if (res.code === 200) {
      promptAction.showToast({ message: '已删除该自动化' })
      router.back()
    }
  }

  /** 把动作 JSON 字符串翻译成人话（尽量），失败就显示原文 */
  private actionText(item: SceneActionItem): string {
    try {
      const obj = JSON.parse(item.action) as Record<string, Object>
      const parts: string[] = []
      const keys: string[] = Object.keys(obj)
      for (let i = 0; i < keys.length; i++) {
        parts.push(`${keys[i]}=${obj[keys[i]]}`)
      }
      return parts.join('，')
    } catch (err) {
      return item.action
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('自动化详情').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.scene === null) {
        EmptyView({ text: '自动化不存在' })
      } else {
        Scroll() {
          Column({ space: Const.CARD_GAP }) {
            // ---------- 基本信息 ----------
            Column({ space: 10 }) {
              Text(this.scene!.name).fontSize(18).fontWeight(FontWeight.Medium)
              Row() {
                Text('触发时间').fontSize(14)
                Blank()
                Text(`每天 ${this.scene!.cronExpr ?? '未设置'}  修改 ›`)
                  .fontSize(14).fontColor(Const.BRAND)
                  .onClick(() => {
                    this.showTimePresets = !this.showTimePresets
                  })
              }.width('100%')
              if (this.showTimePresets) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.timePresets, (time: string) => {
                    Text(time).fontSize(12)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .margin({ right: 8, bottom: 8 })
                      .borderRadius(14)
                      .backgroundColor(this.scene?.cronExpr === time ? Const.BRAND : Const.PAGE_BG)
                      .fontColor(this.scene?.cronExpr === time ? Color.White : Const.TEXT_BODY)
                      .onClick(() => {
                        this.applyTime(time)
                      })
                  }, (time: string) => time)
                }.width('100%')
              }
              Row() {
                Text('启用状态').fontSize(14)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.enabledOn })
                  .selectedColor(Const.BRAND)
                  .onChange((isOn: boolean) => {
                    this.toggle(isOn)
                  })
              }.width('100%')
            }
            .alignItems(HorizontalAlign.Start).width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 执行动作列表 ----------
            Column({ space: 10 }) {
              Text('执行动作').fontSize(14).fontWeight(FontWeight.Medium)
              if ((this.scene!.actions ?? []).length === 0) {
                Text('该自动化还没有配置动作').fontSize(12).fontColor(Const.TEXT_SUB)
              } else {
                ForEach(this.scene!.actions, (item: SceneActionItem, index: number) => {
                  Row() {
                    Text(`设备 #${item.deviceId}`).fontSize(13)
                    Blank()
                    Text(this.actionText(item)).fontSize(12).fontColor(Const.TEXT_SUB)
                  }.width('100%')
                }, (item: SceneActionItem, index: number) => `${item.deviceId}_${index}`)
              }
            }
            .alignItems(HorizontalAlign.Start).width('100%').padding(16)
            .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

            // ---------- 删除 ----------
            Button('删除该自动化')
              .width('100%').height(44).borderRadius(22).margin({ top: 12 })
              .backgroundColor(Const.CARD_BG).fontColor(Const.DANGER)
              .border({ width: 1, color: Const.DANGER })
              .onClick(() => {
                this.remove()
              })
          }.padding({ left: 16, right: 16, bottom: 16 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
