// pages/login/RegisterPage.ets —— 邮箱注册页（验证码注册保持原样，2026-09-29 加手机号）
//
// 流程：填邮箱 + 手机号 → 前端正则校验 → POST /api/user/email/code 发验证码
//       （60 秒有效，存 Redis；60 秒内按钮倒计时不可重发）
//       → 填验证码 + 密码 → POST /api/user/register/email → 成功后用邮箱直接登录
//       → TokenStore.save + saveLastAccount → replaceUrl 回主页（注册完即登录态，不再回登录页）。
// 说明：邮箱注册的用户后端 username 复用邮箱地址，所以登录接口原样可用。
import { router, promptAction } from '@kit.ArkUI'
import { UserApi } from '../../api/UserApi'
import { Const } from '../../common/Const'
import { TokenStore } from '../../common/TokenStore'

/** 邮箱格式（与后端 EmailCodeServiceImpl 的校验口径一致） */
const EMAIL_REGEX: string = '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'

/** 手机号格式（与后端 PHONE_REGEX 一致：11 位、1 开头） */
const PHONE_REGEX: string = '^1[3-9]\\d{9}$'

@Entry
@Component
struct RegisterPage {
  @State email: string = ''
  @State phone: string = ''
  @State nickname: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State code: string = ''
  @State countdown: number = 0            // 重发倒计时（秒），0 = 可发送
  @State loading: boolean = false
  private timerId: number = -1

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)          // 离开页面清掉倒计时，防泄漏
    }
  }

  /** 前端校验：能提前拦掉的错误不要浪费一次请求 */
  checkInput(): string {
    if (!this.email.match(EMAIL_REGEX)) {
      return '请填写正确的邮箱地址'
    }
    if (!this.phone.match(PHONE_REGEX)) {
      return '请填写正确的 11 位手机号'
    }
    if (this.code.length !== 6) {
      return '请填写 6 位验证码'
    }
    if (this.password.length < 6) {
      return '密码至少 6 位'
    }
    if (this.password !== this.confirmPassword) {
      return '两次输入的密码不一致'
    }
    return ''            // 空串 = 校验通过
  }

  /** 发送验证码：先本地校验邮箱，再调后端（后端再校验一次 + 60 秒冷却） */
  async sendCode() {
    if (!this.email.match(EMAIL_REGEX)) {
      promptAction.showToast({ message: '请先填写正确的邮箱地址' })
      return
    }
    if (this.countdown > 0) {
      return
    }
    const res = await UserApi.sendEmailCode(this.email)
    if (res.code === 200) {
      promptAction.showToast({ message: '验证码已发送，60 秒内有效' })
      this.countdown = 60
      this.timerId = setInterval(() => {
        this.countdown--
        if (this.countdown <= 0) {
          clearInterval(this.timerId)
          this.timerId = -1
        }
      }, 1000)
    }
  }

  async doRegister() {
    const err: string = this.checkInput()
    if (err.length > 0) {
      promptAction.showToast({ message: err })
      return
    }
    this.loading = true
    const res = await UserApi.registerByEmail(this.email, this.code, this.phone,
      this.password, this.nickname)
    if (res.code === 200) {
      // 注册成功后自动登录（邮箱就是账号），并直接跳主页 —— 不再退回登录页
      const loginRes = await UserApi.login(this.email, this.password)
      if (loginRes.code === 200 && loginRes.data) {
        const name: string = this.nickname.length > 0
          ? this.nickname : this.email.substring(0, this.email.indexOf('@'))
        await TokenStore.save(loginRes.data, name)
        await TokenStore.saveLastAccount(this.email)   // 下次登录页预填
      }
      promptAction.showToast({ message: '注册成功，已自动登录' })
      // replaceUrl 把注册页换成主页：用户点"返回"不会再回到登录/注册页
      router.replaceUrl({ url: 'pages/Index' })
      return
    }
    this.loading = false
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => { router.back() })
        Blank()
        Text('邮箱注册').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding({ top: 16, bottom: 8 })

      TextInput({ placeholder: '邮箱地址' })
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.email = value })

      TextInput({ placeholder: '手机号（11 位）' })
        .type(InputType.PhoneNumber)
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.phone = value })

      // 验证码行：输入框 + 获取验证码按钮（60 秒倒计时）
      Row({ space: 10 }) {
        TextInput({ placeholder: '6 位验证码' })
          .layoutWeight(1).height(48).backgroundColor(Const.CARD_BG)
          .onChange((value: string) => { this.code = value })
        Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
          .height(48)
          .backgroundColor(this.countdown > 0 ? Const.DIVIDER : Const.BRAND)
          .fontColor(this.countdown > 0 ? Const.TEXT_SUB : Color.White)
          .enabled(this.countdown <= 0)
          .onClick(() => { this.sendCode() })
      }.width('85%')

      TextInput({ placeholder: '昵称（可选）' })
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.nickname = value })

      TextInput({ placeholder: '密码（至少 6 位）' })
        .type(InputType.Password)
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.password = value })

      TextInput({ placeholder: '确认密码' })
        .type(InputType.Password)
        .width('85%').height(48).backgroundColor(Const.CARD_BG)
        .onChange((value: string) => { this.confirmPassword = value })

      Button(this.loading ? '注册中...' : '注册并登录')
        .width('85%').height(46).borderRadius(23)
        .backgroundColor(Const.BRAND).fontColor(Color.White)
        .enabled(!this.loading)
        .onClick(() => { this.doRegister() })

      Text('验证码 60 秒内有效，请查收邮件（注意垃圾箱）')
        .fontSize(11).fontColor(Const.TEXT_SUB)

      Blank()
    }
    .width('100%').height('100%').backgroundColor(Const.PAGE_BG)
  }
}
