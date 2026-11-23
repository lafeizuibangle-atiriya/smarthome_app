// pages/smart/SmartPage.ets —— 底部 Tab·智能（@Component，由 Index 内嵌承载，不是 @Entry！）
//
// 【2026-09-29 重做】页面扩容 + 预设模式卡片化：
//   ① 「预设模式」2 列卡片网格：9 个内置场景（回家/离家/晚安/观影/起床/学习/会客/睡眠/厨房助手），
//      每卡带图标 + 名称 + 中文说明，点卡片一键执行；
//   ② 「自动化（定时触发）」卡片带启停开关 + 定时时间 + 说明；
//   ③ 图标映射 sceneIcon()：icon 字段字符串 → emoji（后端只存 key，样式前端管）。
// 手册 6.5：一键执行 / 自动化启停 / 右上角加号新建，均保留。
import { router, promptAction } from '@kit.ArkUI'
import { SceneApi } from '../../api/SceneApi'
import { Scene } from '../../model/Scene'
import { Const } from '../../common/Const'
import { TokenStore } from '../../common/TokenStore'
import { EmptyView } from '../../view/EmptyView'

@Component
export struct SmartPage {
  /** 刷新信号：Index 每次 +1 就重新拉一次场景列表（登录/退出后要跟着变，踩坑 11） */
  @Prop @Watch('onSignalChange') refreshTick: number = 0

  @State manualScenes: Scene[] = []     // 手动场景：点击即执行（预设模式卡片区）
  @State autoScenes: Scene[] = []       // 自动化：定时触发，有启停开关
  @State isLogin: boolean = false

  /** 信号变化：重新拉一次数据（未登录时不发请求，先判登录态） */
  onSignalChange() {
    this.loadAll()
  }

  aboutToAppear() {
    this.loadAll()
  }

  async loadAll() {
    this.isLogin = TokenStore.isLogin()
    if (!this.isLogin) {
      // 未登录清空列表，避免残留上一个账号的数据
      this.manualScenes = []
      this.autoScenes = []
      return
    }
    const manual = await SceneApi.list('MANUAL')
    if (manual.code === 200 && manual.data) {
      this.manualScenes = manual.data
    }
    const auto = await SceneApi.list('TIMER')
    if (auto.code === 200 && auto.data) {
      this.autoScenes = auto.data
    }
  }

  /** 执行场景并提示结果 */
  async runScene(scene: Scene) {
    const res = await SceneApi.run(scene.id)
    if (res.code === 200) {
      promptAction.showToast({ message: `已执行「${scene.name}」` })
    } else {
      promptAction.showToast({ message: res.msg })
    }
  }

  /** 启停自动化 */
  async toggleAuto(scene: Scene) {
    const next: number = scene.enabled === 1 ? 0 : 1
    const res = await SceneApi.toggle(scene.id, next)
    if (res.code === 200) {
      // 数组元素就地赋值不触发 @State 刷新：slice() 造新数组再整体赋值（踩坑 14）
      const nextList: Scene[] = this.autoScenes.slice()
      for (let i = 0; i < nextList.length; i++) {
        if (nextList[i].id === scene.id) {
          nextList[i].enabled = next
        }
      }
      this.autoScenes = nextList
    }
  }

  /** 场景图标：icon 字段 key → emoji（未登记的 key 回落圆点） */
  private sceneIcon(key: string): string {
    if (key === 'home') {
      return '🏠'
    }
    if (key === 'away') {
      return '🚪'
    }
    if (key === 'night') {
      return '🌙'
    }
    if (key === 'movie') {
      return '🎬'
    }
    if (key === 'sun') {
      return '☀️'
    }
    if (key === 'book') {
      return '📚'
    }
    if (key === 'guest') {
      return '🍵'
    }
    if (key === 'moon') {
      return '🛏️'
    }
    if (key === 'kitchen') {
      return '🍳'
    }
    return '🔘'
  }

  /** 卡片图标底色：不同模式给不同的浅色底，页面更"米家" */
  private sceneIconBg(key: string): string {
    if (key === 'home') {
      return '#E8F3E9'
    }
    if (key === 'away') {
      return '#EDEAF8'
    }
    if (key === 'night') {
      return '#E3EAF8'
    }
    if (key === 'movie') {
      return '#F8E9E3'
    }
    if (key === 'sun') {
      return '#FFF4DC'
    }
    if (key === 'book') {
      return '#E4F2F4'
    }
    if (key === 'guest') {
      return '#F4EFE4'
    }
    if (key === 'moon') {
      return '#E9E9F6'
    }
    if (key === 'kitchen') {
      return '#FDEEDF'
    }
    return Const.BRAND_LIGHT
  }

  build() {
    Column() {
      Row() {
        Text('智能').fontSize(20).fontWeight(FontWeight.Medium)
        Blank()
        Text('+').fontSize(26).fontColor(Const.BRAND)
          .onClick(() => {
            if (!TokenStore.isLogin()) {
              router.pushUrl({ url: 'pages/login/LoginPage' })
              return
            }
            router.pushUrl({ url: 'pages/smart/SceneEditPage' })
          })
      }.width('100%').padding(16)

      Scroll() {
        Column({ space: Const.CARD_GAP }) {
          // ---------- 预设模式（2 列卡片，一键执行） ----------
          Row() {
            Text('预设模式').fontSize(14).fontWeight(FontWeight.Medium)
            Blank()
            Text('点卡片立即执行').fontSize(11).fontColor(Const.TEXT_SUB)
          }.width('100%').margin({ bottom: 4 })

          if (this.manualScenes.length === 0) {
            EmptyView({ text: '还没有手动场景，点右上角 + 新建' })
          } else {
            // 两列卡片铺满全宽：48% + 右距 4% + 48% = 100%
            // 旧写法每张都带右距（104% 超宽）→ Flex 每行只放下一张、右侧全空（2026-09-27 修）
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.manualScenes, (scene: Scene, idx: number) => {
                Column({ space: 6 }) {
                  Text(this.sceneIcon(scene.icon ?? ''))
                    .fontSize(24)
                    .width(44).height(44)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.sceneIconBg(scene.icon ?? ''))
                    .borderRadius(14)
                  Text(scene.name)
                    .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(scene.description ?? '一键联动多个设备')
                    .fontSize(11).fontColor(Const.TEXT_SUB)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .height(30)
                }
                .alignItems(HorizontalAlign.Start)
                .width('48%')
                .margin({ right: idx % 2 === 0 ? '4%' : 0, bottom: 10 })
                .padding(12)
                .backgroundColor(Const.CARD_BG)
                .borderRadius(Const.CARD_RADIUS)
                .onClick(() => {
                  this.runScene(scene)
                })
              }, (scene: Scene) => `${scene.id}_${scene.enabled}_${scene.name}_${scene.description ?? ''}`)
            }
            .width('100%')
          }

          // ---------- 自动化（定时触发） ----------
          Text('自动化（定时触发）').fontSize(14).fontWeight(FontWeight.Medium)
            .width('100%').margin({ top: 8, bottom: 4 })
          if (this.autoScenes.length === 0) {
            EmptyView({ text: '还没有自动化，点右上角 + 新建' })
          } else {
            ForEach(this.autoScenes, (scene: Scene) => {
              Row({ space: 12 }) {
                Text(this.sceneIcon(scene.icon ?? ''))
                  .fontSize(22)
                  .width(42).height(42)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.sceneIconBg(scene.icon ?? ''))
                  .borderRadius(12)
                Column({ space: 4 }) {
                  Text(scene.name).fontSize(15).fontColor(Const.TEXT_MAIN)
                  Text(`定时：${scene.cronExpr ?? '未设置'} · ${scene.description ?? ''}`)
                    .fontSize(11).fontColor(Const.TEXT_SUB)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: scene.enabled === 1 })
                  .selectedColor(Const.BRAND)
                  .onChange(() => {
                    this.toggleAuto(scene)
                  })
              }
              .width('100%').padding(14)
              .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/smart/AutoDetailPage', params: { sceneId: scene.id }
                })
              })
            }, (scene: Scene) => `${scene.id}_${scene.enabled}_${scene.name}_${scene.description ?? ''}`)
          }
        }.padding({ left: 16, right: 16, bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
