// model/User.ets —— 【阶段① · C 负责】用户与收货地址数据模型
// 字段与后端 VO 一一对应，不要自己加字段（加字段先改 docs/03_接口文档.md）。
//
// 【为什么必须写 interface】ArkTS 严格模式（手册 5.0）不允许 any/unknown，
// 也不允许把裸对象字面量传给 object 参数。有了这里的 interface，
// api 层才能 `const body: LoginParam = {...}` 这样"先声明再赋值"。

export interface UserInfo {
  id: number
  username: string
  nickname: string
  avatar?: string
  deviceCount?: number    // 后端统计后返回，用于"我的"页展示（阶段① 先返回 0 占位）
  orderCount?: number     // 同上
  orderPending?: number   // 待付款订单数（status=0），"我的"页订单快捷入口
  orderPaid?: number      // 已付款订单数（status=1），同上
}

export interface Address {
  id: number
  receiver: string
  phone: string
  region: string          // 省市区
  detail: string          // 详细地址
  isDefault: number       // 1 默认，0 非默认
}
