// pages/login/LoginPage.ets —— 【阶段① · D 负责】登录页（@Entry 子页面，已在 main_pages.json 登记）
// 结构照手册 6.15。
//
// 流程：输入账号密码 → UserApi.login 拿 token → TokenStore.save 落盘 → router.back() 回来源页。
// 【2026-09-29 改造】
//   ① 账号支持 用户名 / 手机号 / 邮箱 任一标识（后端 login 三查，前端只改提示文案）；
//   ② 记住上次登录的账号：aboutToAppear 从 TokenStore 读 lastAccount 预填，
//      只记住账号、绝不存密码（安全红线）；
// 【提醒】登录成功回 Index 后靠 refreshTick 信号刷新各 Tab（踩坑 11），
//         这一步不用在这里做——Index.onPageShow 会自动广播。
import { router, promptAction } from '@kit.ArkUI'   // promptAction 必须显式 import，漏了报 Cannot find name
import { UserApi } from '../../api/UserApi'
import { Const } from '../../common/Const'
import { TokenStore } from '../../common/TokenStore'

@Entry
@Component
struct LoginPage {
  @State username: string = ''
  @State password: string = ''
  @State loading: boolean = false

  aboutToAppear() {
    // 预填上次登录的账号（只填账号，密码永远要重新输）
    const last: string = TokenStore.getLastAccount()
    if (last.length > 0) {
      this.username = last
    }
  }

  async doLogin() {
    // 前端先做基础校验，减少无效请求
    if (this.username.length === 0 || this.password.length === 0) {
      promptAction.showToast({ message: '请输入账号和密码' })
      return
    }
    this.loading = true
    // 失败时不用 here 处理：HttpClient 已统一把 code!=200 的 msg 弹成 Toast
    // （400 业务错不节流，每次点都会提示）
    const res = await UserApi.login(this.username, this.password)
    this.loading = false
    if (res.code === 200 && res.data) {
      // 登录成功：保存 token，记住本次账号（下次打开自动预填）。
      // 昵称先暂存账号 —— /api/user/login 只返回 token，不含昵称；
      // "我的"页 refresh() 会再调 /api/user/info 拿到真实昵称并覆盖显示。
      await TokenStore.save(res.data, this.username)
      await TokenStore.saveLastAccount(this.username)
      promptAction.showToast({ message: '登录成功' })
      router.back()
    }
  }

  build() {
    Column({ space: 16 }) {
      Text('智慧生活').fontSize(28).fontWeight(FontWeight.Medium)
        .fontColor(Const.BRAND).margin({ top: 80, bottom: 24 })

      TextInput({ text: this.username, placeholder: '用户名 / 手机号 / 邮箱' })
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.username = value })

      TextInput({ placeholder: '密码' })
        .type(InputType.Password)
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.password = value })

      Button(this.loading ? '登录中...' : '登录')
        .width('85%').height(46).borderRadius(23)
        .backgroundColor(Const.BRAND).fontColor(Color.White)
        .enabled(!this.loading)      // 防重复提交
        .onClick(() => { this.doLogin() })

      Row({ space: 4 }) {
        Text('还没有账号？').fontSize(13).fontColor(Const.TEXT_SUB)
        Text('立即注册').fontSize(13).fontColor(Const.BRAND)
          .onClick(() => { router.pushUrl({ url: 'pages/login/RegisterPage' }) })
      }

      Text('演示账号：demo / 123456').fontSize(12).fontColor(Const.TEXT_SUB)
        .margin({ top: 20 })

      Blank()
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
