// view/SectionTitle.ets —— 区块标题（通用）
import { Const } from '../common/Const'

@Component
export struct SectionTitle {
  @Prop title: string = ''
  @Prop moreText: string = ''          // 传非空时右侧显示"更多"
  onMore: () => void = () => {}

  build() {
    Row() {
      Text(this.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Const.TEXT_MAIN)
      Blank()
      if (this.moreText.length > 0) {
        Text(this.moreText).fontSize(12).fontColor(Const.TEXT_SUB)
          .onClick(() => this.onMore())
      }
    }
    .width('100%').margin({ top: 4, bottom: 4 })
  }
}
