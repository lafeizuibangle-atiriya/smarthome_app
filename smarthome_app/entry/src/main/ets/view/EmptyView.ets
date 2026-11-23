// view/EmptyView.ets —— 空态组件（前端手册 4.6，所有列表页空数据都要用）
import { Const } from '../common/Const'

@Component
export struct EmptyView {
  @Prop text: string = '暂无数据'
  @Prop buttonText: string = ''
  onAction: () => void = () => {}

  build() {
    Column({ space: 12 }) {
      Circle({ width: 56, height: 56 }).fill('#EEEEEE')     // 占位图标
      Text(this.text).fontSize(14).fontColor(Const.TEXT_SUB)
      if (this.buttonText.length > 0) {
        Button(this.buttonText)
          .height(36).borderRadius(18).fontSize(13)
          .backgroundColor(Const.BRAND).fontColor(Color.White)
          .onClick(() => this.onAction())
      }
    }
    .width('100%').padding({ top: 60, bottom: 60 })
  }
}
