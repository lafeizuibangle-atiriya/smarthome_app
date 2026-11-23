// pages/device/AddDevicePage.ets —— 添加设备页（@Entry 子页面，手册 6.18）
// 选择房间 -> 选择设备类型（5 种，图标卡片网格）-> 填名称 -> 提交（模拟"配网"进度条 2 秒）。
// 【四处同步】类型数组必须与 Const / deviceTypeName() / 后端 DeviceServiceImpl.types() 一致。
import { router, promptAction } from '@kit.ArkUI'
import { DeviceApi } from '../../api/DeviceApi'
import { Room } from '../../model/Device'
import { Const, deviceTypeName, deviceTypeIcon } from '../../common/Const'

@Entry
@Component
struct AddDevicePage {
  @State rooms: Room[] = []
  @State currentRoomIndex: number = 0
  @State deviceName: string = ''
  @State selectedType: string = Const.DEV_LIGHT
  @State pairing: boolean = false          // 模拟配网中
  @State progress: number = 0

  // 设备类型字典：Demo 内联（要与后端 DeviceTypes.ALL 保持一致，共 7 种）
  private types: string[] = [
    Const.DEV_LIGHT, Const.DEV_FAN, Const.DEV_GATE, Const.DEV_BEEP,
    Const.DEV_SMOKE_SENSOR, Const.DEV_ENV_SENSOR, Const.DEV_PIR_SENSOR
  ]

  aboutToAppear() {
    this.loadRooms()
  }

  async loadRooms() {
    const res = await DeviceApi.roomList()
    if (res.code === 200 && res.data) {
      this.rooms = res.data
    }
  }

  /**
   * 添加设备：先跑 2 秒"模拟配网"进度条，再真正调接口。
   * 目的：让 Demo 看起来像真实的设备配网流程。
   */
  addDevice() {
    if (this.rooms.length === 0) {
      promptAction.showToast({ message: '请先创建房间' })
      return
    }
    if (this.deviceName.length === 0) {
      promptAction.showToast({ message: '请输入设备名称' })
      return
    }
    this.pairing = true
    // 模拟配网进度：每 200ms +10%
    const timer = setInterval(() => {
      this.progress += 10
      if (this.progress >= 100) {
        clearInterval(timer)
      }
    }, 200)

    setTimeout(async () => {
      const roomId: number = this.rooms[this.currentRoomIndex].id
      const res = await DeviceApi.addDevice(roomId, this.deviceName, this.selectedType)
      this.pairing = false
      this.progress = 0
      if (res.code === 200) {
        promptAction.showToast({ message: '设备添加成功' })
        router.back()
      }
    }, 2200)
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('添加设备').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      if (this.pairing) {
        // 配网进度界面
        Column({ space: 16 }) {
          Text('正在连接设备...').fontSize(16)
          Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
            .width('70%').color(Const.BRAND)
          Text(`${this.progress}%`).fontSize(13).fontColor(Const.TEXT_SUB)
        }.margin({ top: 120 })
      } else {
        // 表单区套 Scroll（2026-09-30 修复"划不动、看不到下面的设备"）：
        // 17 种类型网格 + 名称输入 + 添加按钮的总高远超一屏，之前直接放在根
        // Column 里会被整页裁掉，底部的类型 / 名称框 / 按钮既看不见也够不着。
        // layoutWeight(1) 让 Scroll 占满标题栏以下的剩余高度，内容超高即可滚动。
        Scroll() {
          Column({ space: 16 }) {
            Text('选择房间').fontSize(14).fontWeight(FontWeight.Medium)
              .width('100%').align(Alignment.Start)
            Row({ space: 8 }) {
              ForEach(this.rooms, (room: Room, index: number) => {
                Text(room.name).fontSize(13)
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .borderRadius(16)
                  .backgroundColor(index === this.currentRoomIndex ? Const.BRAND : Const.CARD_BG)
                  .fontColor(index === this.currentRoomIndex ? Color.White : Const.TEXT_MAIN)
                  .onClick(() => {
                    this.currentRoomIndex = index
                  })
              }, (room: Room) => `${room.id}_${room.name}`)
            }.width('100%')

            Text('选择设备类型').fontSize(14).fontWeight(FontWeight.Medium)
              .width('100%').align(Alignment.Start)
            Grid() {
              ForEach(this.types, (type: string) => {
                GridItem() {
                  Column({ space: 6 }) {
                    Text(deviceTypeIcon(type))
                      .fontSize(24)
                      .width(52).height(52)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(type === this.selectedType ? Const.BRAND_LIGHT : '#F2F3F5')
                      .borderRadius(16)
                    Text(deviceTypeName(type))
                      .fontSize(12)
                      .fontColor(type === this.selectedType ? Const.BRAND : Const.TEXT_MAIN)
                      .fontWeight(type === this.selectedType ? FontWeight.Medium : FontWeight.Normal)
                  }
                  .padding({ top: 12, bottom: 10 })
                  .width('100%')
                  .backgroundColor(Const.CARD_BG)
                  .borderRadius(16)
                  .border({ width: 1.5, color: type === this.selectedType ? Const.BRAND : 'transparent' })
                  .onClick(() => {
                    this.selectedType = type
                  })
                }
              }, (type: string) => type)
            }
            .columnsTemplate('1fr 1fr 1fr')
            .columnsGap(10)
            .rowsGap(10)
            // 显式给满 6 行的总高：网格整块渲染、不在 Scroll 里再嵌套滚动，
            // 页面级滚动交给外层 Scroll，避免两层滚动手势打架
            .height(Math.ceil(this.types.length / 3) * 106 + 10)

            Text('设备名称').fontSize(14).fontWeight(FontWeight.Medium)
              .width('100%').align(Alignment.Start)
            TextInput({ placeholder: '例如：客厅主灯' })
              .width('100%').height(48).backgroundColor(Const.CARD_BG)
              .onChange((value: string) => {
                this.deviceName = value
              })

            Button('开始配网并添加')
              .width('100%').height(46).borderRadius(23)
              .backgroundColor(Const.BRAND).fontColor(Color.White)
              .onClick(() => {
                this.addDevice()
              })
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
