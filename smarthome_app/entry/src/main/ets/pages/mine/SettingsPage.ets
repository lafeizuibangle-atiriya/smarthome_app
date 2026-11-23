// pages/mine/SettingsPage.ets —— 设置页（@Entry 子页面，自研实现）
// 收货地址管理（增/删）+ 关于我们 + 退出登录。
// 地址增删是用户主动操作且留在本页 → 明确 toast（手册 4.3.2）。
import { router, promptAction } from '@kit.ArkUI'
import { UserApi, AddressParam } from '../../api/UserApi'
import { Address } from '../../model/User'
import { Const } from '../../common/Const'
import { TokenStore } from '../../common/TokenStore'
import { EmptyView } from '../../view/EmptyView'

@Entry
@Component
struct SettingsPage {
  @State addresses: Address[] = []
  @State adding: boolean = false
  @State receiver: string = ''
  @State phone: string = ''
  @State region: string = ''
  @State detail: string = ''

  aboutToAppear() {
    this.load()
  }

  async load() {
    const res = await UserApi.addressList()
    if (res.code === 200 && res.data) {
      this.addresses = res.data
    }
  }

  /** 新增地址：表单校验 → 提交 → 刷新列表 */
  async submitAddress() {
    if (this.receiver.length === 0 || this.phone.length === 0
        || this.region.length === 0 || this.detail.length === 0) {
      promptAction.showToast({ message: '请填写完整的地址信息' })
      return
    }
    const param: AddressParam = {
      receiver: this.receiver,
      phone: this.phone,
      region: this.region,
      detail: this.detail,
      isDefault: this.addresses.length === 0 ? 1 : 0    // 第一条自动设为默认
    }
    const res = await UserApi.addAddress(param)
    if (res.code === 200) {
      promptAction.showToast({ message: '地址已添加' })
      this.adding = false
      this.receiver = ''
      this.phone = ''
      this.region = ''
      this.detail = ''
      this.load()
    }
  }

  async removeAddress(address: Address) {
    const res = await UserApi.removeAddress(address.id)
    if (res.code === 200) {
      promptAction.showToast({ message: '已删除' })
      this.load()
    }
  }

  async logout() {
    await TokenStore.clear()
    promptAction.showToast({ message: '已退出登录' })
    router.back()
  }

  @Builder
  addressForm() {
    Column({ space: 10 }) {
      TextInput({ placeholder: '收货人姓名' })
        .height(44).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => {
          this.receiver = value
        })
      TextInput({ placeholder: '手机号' })
        .height(44).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => {
          this.phone = value
        })
      TextInput({ placeholder: '省市区（如：广东省 深圳市 南山区）' })
        .height(44).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => {
          this.region = value
        })
      TextInput({ placeholder: '详细地址（如：科技园路 1 号 101 室）' })
        .height(44).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => {
          this.detail = value
        })
      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor(Const.CARD_BG).fontColor(Const.TEXT_SUB)
          .onClick(() => {
            this.adding = false
          })
        Button('保存')
          .layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor(Const.BRAND).fontColor(Color.White)
          .onClick(() => {
            this.submitAddress()
          })
      }.width('100%').margin({ top: 4 })
    }
    .width('100%').padding(16)
    .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('设置').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      Scroll() {
        Column({ space: Const.CARD_GAP }) {
          // ---------- 收货地址管理 ----------
          Row() {
            Text('收货地址').fontSize(14).fontWeight(FontWeight.Medium)
            Blank()
            Text(this.adding ? '' : '+ 新增').fontSize(13).fontColor(Const.BRAND)
              .onClick(() => {
                this.adding = true
              })
          }.width('100%')

          if (this.adding) {
            this.addressForm()
          }

          if (this.addresses.length === 0 && !this.adding) {
            EmptyView({ text: '还没有收货地址', buttonText: '新增地址',
              onAction: () => {
                this.adding = true
              } })
          } else {
            ForEach(this.addresses, (address: Address) => {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(`${address.receiver}　${address.phone}`).fontSize(14)
                    if (address.isDefault === 1) {
                      Text('默认').fontSize(10).fontColor(Color.White)
                        .backgroundColor(Const.BRAND).borderRadius(4)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    }
                  }
                  Text(`${address.region} ${address.detail}`)
                    .fontSize(12).fontColor(Const.TEXT_SUB)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('删除').fontSize(13).fontColor(Const.DANGER)
                  .onClick(() => {
                    this.removeAddress(address)
                  })
              }
              .width('100%').padding(14)
              .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)
            }, (address: Address) => `${address.id}_${address.receiver}_${address.detail}`)
          }

          // ---------- 关于 ----------
          Row() {
            Text('关于我们').fontSize(14)
            Blank()
            Text('智慧家居 Demo v1.0').fontSize(12).fontColor(Const.TEXT_SUB)
          }
          .width('100%').padding(16)
          .backgroundColor(Const.CARD_BG).borderRadius(Const.CARD_RADIUS)

          // ---------- 退出登录 ----------
          if (TokenStore.isLogin()) {
            Button('退出登录')
              .width('100%').height(44).borderRadius(22).margin({ top: 12 })
              .backgroundColor(Const.CARD_BG).fontColor(Const.DANGER)
              .onClick(() => {
                this.logout()
              })
          }
        }.padding({ left: 16, right: 16, bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
