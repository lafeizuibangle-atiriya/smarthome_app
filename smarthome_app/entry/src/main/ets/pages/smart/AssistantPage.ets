// pages/smart/AssistantPage.ets —— AI 助手对话页（2026-11-23 新增）
// 对接后端 POST /api/assistant/chat：普通问题直接回答，控制类指令会真的操作设备。
// 结构：顶栏返回 + 消息气泡列表（用户右绿 / 助手左白）+ 示例问题胶囊 + 底部输入条。
import { router } from '@kit.ArkUI'
import { AssistantApi, ChatResult } from '../../api/AssistantApi'
import { Const } from '../../common/Const'

/** 一条消息。role：'user' 用户 / 'bot' 助手 */
interface MsgItem {
  role: string
  text: string
}

/** 示例问题胶囊数据 */
interface SampleItem {
  text: string
}

@Entry
@Component
struct AssistantPage {
  @State msgs: MsgItem[] = [{
    role: 'bot',
    text: '你好，我是智慧家居助手。可以问我家里的情况，也可以让我控制设备。\n试试下面的问题，或直接输入。'
  }]
  @State input: string = ''
  @State sending: boolean = false          // 请求中：输入框和发送按钮禁用
  private scroller: Scroller = new Scroller()

  /** 示例问题：点一下直接发送（覆盖三种能力：状态查询 / 设备控制 / 模式切换） */
  @State samples: SampleItem[] = [
    { text: '现在家里温度怎么样？' },
    { text: '客厅有点暗啊' },
    { text: '让家里自己联动起来' }
  ]

  /** 发送一条消息。请求期间显示"思考中…"占位，收到回复后原地替换 */
  async send(text: string) {
    const q: string = text.trim()
    if (q.length === 0 || this.sending) {
      return
    }
    this.msgs.push({ role: 'user', text: q })
    this.input = ''
    this.sending = true
    this.msgs.push({ role: 'bot', text: '思考中…' })
    this.scrollToBottom()

    const res = await AssistantApi.chat(q)
    // 把占位气泡替换为真实回复（失败也给一句兜底，不让气泡停在"思考中"）
    let reply: string = '网络异常，请检查后端服务'
    if (res.code === 200 && res.data !== undefined) {
      const data: ChatResult = res.data
      reply = data.reply
    } else if (res.code !== 200 && res.msg.length > 0) {
      reply = res.msg
    }
    this.msgs.splice(this.msgs.length - 1, 1, { role: 'bot', text: reply })
    this.sending = false
    this.scrollToBottom()
  }

  /** 消息列表滚到底部（新消息在下方出现） */
  private scrollToBottom() {
    // 等一帧让布局完成再滚，否则滚不到真正的底部
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 100)
  }

  build() {
    Column() {
      // ---------- 顶栏（与房间管理等子页一致） ----------
      Row() {
        Text('‹ 返回').fontSize(16).onClick(() => router.back())
        Blank()
        Text('AI 助手').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text('　').fontSize(16)
      }.width('100%').padding(16)

      // ---------- 消息列表 ----------
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          ForEach(this.msgs, (msg: MsgItem, index: number) => {
            Row() {
              if (msg.role === 'user') {
                Blank()
                Text(msg.text)
                  .fontSize(15).fontColor(Color.White)
                  .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                  .backgroundColor(Const.BRAND_BLUE)
                  .borderRadius(16)
                  .constraintSize({ maxWidth: '78%' })
              } else {
                Text(msg.text)
                  .fontSize(15).fontColor(Const.TEXT_MAIN)
                  .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                  .backgroundColor(Const.CARD_BG)
                  .borderRadius(16)
                  .constraintSize({ maxWidth: '78%' })
                Blank()
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Bottom)
          }, (msg: MsgItem, index: number) => `${index}_${msg.role}_${msg.text}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(Const.PAGE_BG)

      // ---------- 示例问题胶囊（只在对话刚开始时展示） ----------
      if (this.msgs.length <= 2) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.samples, (s: SampleItem) => {
            Text(s.text)
              .fontSize(12).fontColor(Const.BRAND_BLUE)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(Const.BRAND_BLUE_LIGHT)
              .borderRadius(16)
              .onClick(() => {
                this.send(s.text)
              })
          }, (s: SampleItem) => s.text)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }

      // ---------- 底部输入条 ----------
      Row({ space: 10 }) {
        TextInput({ text: this.input, placeholder: '输入问题，如：打开客厅的灯' })
          .layoutWeight(1).height(42).backgroundColor(Const.PAGE_BG)
          .enabled(!this.sending)
          .onChange((value: string) => {
            this.input = value
          })
          .onSubmit(() => {
            this.send(this.input)
          })
        Button(this.sending ? '…' : '发送')
          .height(42).borderRadius(21)
          .backgroundColor(this.sending ? Const.SWITCH_OFF : Const.BRAND)
          .fontColor(Color.White)
          .enabled(!this.sending)
          .onClick(() => {
            this.send(this.input)
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
      .backgroundColor(Const.CARD_BG)
    }
    .width('100%').height('100%')
    .backgroundColor(Const.PAGE_BG)
  }
}
