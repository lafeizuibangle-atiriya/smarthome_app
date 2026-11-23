// pages/home/RoomManagePage.ets —— 房间管理页（@Entry 子页面，自研实现）
// 房间列表增删改（DeviceApi.addRoom / renameRoom / removeRoom）。
// 返回首页后 Index.onPageShow 会广播 refreshTick，主页自动重拉（踩坑 11 的设计闭环）。
import { router, promptAction } from '@kit.ArkUI'
import { DeviceApi } from '../../api/DeviceApi'
import { Room } from '../../model/Device'
import { Const } from '../../common/Const'
import { EmptyView } from '../../view/EmptyView'

@Entry
@Component
struct RoomManagePage {
  @State rooms: Room[] = []
  @State newRoomName: string = ''
  @State editingId: number = -1            // 正在重命名的房间 id（-1 = 无）
  @State editingName: string = ''

  aboutToAppear() {
    this.load()
  }

  async load() {
    const res = await DeviceApi.roomList()
    if (res.code === 200 && res.data) {
      this.rooms = res.data
    }
  }

  /** 新增房间：用户主动操作且留在本页 → 明确 toast（手册 4.3.2） */
  async addRoom() {
    if (this.newRoomName.length === 0) {
      promptAction.showToast({ message: '请输入房间名称' })
      return
    }
    const res = await DeviceApi.addRoom(this.newRoomName)
    if (res.code === 200) {
      promptAction.showToast({ message: '房间已添加' })
      this.newRoomName = ''
      this.load()
    }
  }

  async renameRoom() {
    if (this.editingName.length === 0) {
      promptAction.showToast({ message: '请输入新名称' })
      return
    }
    const res = await DeviceApi.renameRoom(this.editingId, this.editingName)
    if (res.code === 200) {
      promptAction.showToast({ message: '已重命名' })
      this.editingId = -1
      this.load()
    }
  }

  async removeRoom(room: Room) {
    const res = await DeviceApi.removeRoom(room.id)
    if (res.code === 200) {
      promptAction.showToast({ message: '房间已删除' })
      this.load()
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('房间管理').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      Scroll() {
        Column({ space: Const.CARD_GAP }) {
          // ---------- 新增房间 ----------
          Column({ space: 10 }) {
            Text('新增房间').fontSize(14).fontWeight(FontWeight.Medium)
            Row({ space: 10 }) {
              TextInput({ placeholder: '例如：书房' })
                .layoutWeight(1).height(44).backgroundColor(Const.PAGE_BG)
                .onChange((value: string) => {
                  this.newRoomName = value
                })
              Button('添加')
                .height(44).borderRadius(22)
                .backgroundColor(Const.BRAND).fontColor(Color.White)
                .onClick(() => {
                  this.addRoom()
                })
            }.width('100%')
          }
          .alignItems(HorizontalAlign.Start).width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // ---------- 房间列表 ----------
          Text('房间列表').fontSize(14).fontWeight(FontWeight.Medium).width('100%')
          if (this.rooms.length === 0) {
            EmptyView({ text: '还没有房间' })
          } else {
            ForEach(this.rooms, (room: Room) => {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Text(room.name).fontSize(15).layoutWeight(1)
                  Text('重命名').fontSize(13).fontColor(Const.BRAND)
                    .onClick(() => {
                      this.editingId = room.id
                      this.editingName = room.name
                    })
                  Text('删除').fontSize(13).fontColor(Const.DANGER)
                    .onClick(() => {
                      this.removeRoom(room)
                    })
                }.width('100%')

                // 点了"重命名"的那一行，展开输入框
                if (this.editingId === room.id) {
                  Row({ space: 10 }) {
                    TextInput({ text: this.editingName })
                      .layoutWeight(1).height(40).backgroundColor(Const.PAGE_BG)
                      .onChange((value: string) => {
                        this.editingName = value
                      })
                    Button('保存')
                      .height(40).borderRadius(20)
                      .backgroundColor(Const.BRAND).fontColor(Color.White)
                      .onClick(() => {
                        this.renameRoom()
                      })
                  }.width('100%')
                }
              }
              .alignItems(HorizontalAlign.Start).width('100%').padding(14)
              .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
            }, (room: Room) => `${room.id}_${room.name}_${this.editingId === room.id ? 1 : 0}`)
          }
        }.padding({ left: 16, right: 16, bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
