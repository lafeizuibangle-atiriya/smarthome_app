// view/NumberStepper.ets —— 数量步进器（前端手册 6.10，购物车 / 商品详情共用）
import { Const } from '../common/Const'

@Component
export struct NumberStepper {
  @Prop value: number = 1
  @Prop min: number = 1
  @Prop max: number = 999
  onValueChange: (value: number) => void = () => {}

  build() {
    Row() {
      Text('−')
        .width(28).height(28).textAlign(TextAlign.Center)
        .borderRadius(4).backgroundColor('#F2F2F2')
        .fontColor(this.value <= this.min ? '#CCCCCC' : Const.TEXT_MAIN)
        .onClick(() => {
          if (this.value > this.min) {
            this.onValueChange(this.value - 1)
          }
        })
      Text(this.value.toString())
        .width(40).textAlign(TextAlign.Center).fontSize(14)
      Text('+')
        .width(28).height(28).textAlign(TextAlign.Center)
        .borderRadius(4).backgroundColor('#F2F2F2')
        .fontColor(this.value >= this.max ? '#CCCCCC' : Const.TEXT_MAIN)
        .onClick(() => {
          if (this.value < this.max) {
            this.onValueChange(this.value + 1)
          }
        })
    }
  }
}
